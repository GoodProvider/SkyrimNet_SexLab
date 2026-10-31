#pragma once
// MagelightUI_Mod.h — header-only convenience wrapper over the Magelight C
// ABI (MagelightUI_API.h). Optional: it hides the boilerplate every C++
// consumer would otherwise write by hand — RegisterMod/UnregisterMod
// lifetime, the ViewDesc/ModDesc `size` fields, and demultiplexing the one
// `onEvent` callback into per-view close/error slots.
//
// You still call the raw vtable (mod.v4()->RequestUIMode(...), etc.) for
// everything the wrapper does not cover; this only owns the tedious parts.
// If you want zero abstraction, ignore this header and use MagelightUI_API.h
// directly — nothing here is required.
//
//   MAGELIGHT_API::MagelightMod mod;
//   if (!mod.acquire("MyMod", "My Mod", 0,16,0)) return;   // host absent/too old
//   const auto view = mod.createView("panel",
//       R"(C:\...\Data\Magelight\MyMod\views\panel\index.html)",
//       MAGELIGHT_API::Layer::Panel, { .fullscreen = true });
//   mod.onClose(view, [](MAGELIGHT_API::ViewId){ /* Escape / key closed it */ });
//   mod.v4()->BindHotkey(view, /*dxScancode*/ 0x64 /*F13*/, MAGELIGHT_API::kHotkeyActionToggleUIMode);
//
// Thread: the close/error slots run on the callback thread you pass to
// acquire() (default GameThread — the only thread where RE:: engine state is
// safe). Everything here is a thin forward to the vtable; no game state is
// touched.
//
// C++17. Depends only on MagelightUI_API.h and the standard library.

#include "MagelightUI_API.h"

#include <cstdint>
#include <functional>
#include <map>
#include <mutex>
#include <string>

namespace MAGELIGHT_API {

    class MagelightMod {
    public:
        // Extra view knobs (all optional; the defaults match a plain panel).
        struct ViewOpts {
            bool          fullscreen   = false;   // track the backbuffer; ignore x/y/w/h
            bool          clickThrough = false;   // HUD widgets: input passes through
            bool          startVisible = false;
            Anchor        anchor       = Anchor::TopLeft;
            std::int32_t  x = 0, y = 0, w = 0, h = 0;   // required unless fullscreen
            float         uiScale      = 0.0f;    // 0 = host default
            DomReadyFn    onDomReady   = nullptr; // fires when the page's DOM is ready
            std::uint32_t hibernateMs  = 0;       // >0: release the View+texture after this long hidden
        };

        MagelightMod() = default;
        ~MagelightMod() { release(); }
        MagelightMod(const MagelightMod&) = delete;
        MagelightMod& operator=(const MagelightMod&) = delete;

        /// Acquire the host and register this mod. Returns false if Magelight
        /// is absent or older than the version you require (the host logs the
        /// too-old reason under its own name; check v1()==nullptr to tell
        /// "absent" from "too old"). Call once, after SKSE kDataLoaded.
        bool acquire(const char* modId, const char* displayName,
                     std::uint32_t minMajor, std::uint32_t minMinor, std::uint32_t minPatch,
                     CallbackThread thread = CallbackThread::GameThread,
                     const char* sessionName = nullptr)
        {
            if (m_mod) return true;   // already acquired
            m_v1 = RequestApi();
            m_v4 = RequestApi4();
            if (!m_v1 || !m_v4) return false;   // absent, or older than v4 (0.10.0)
            ModDesc d{};
            d.size            = sizeof(d);
            d.modId           = modId;
            d.displayName     = displayName;
            d.modVersion      = 0;
            d.minHostVersion  = PackVersion(minMajor, minMinor, minPatch);
            d.callbackThread  = thread;
            d.onEvent         = &MagelightMod::dispatch;
            d.onLog           = nullptr;
            d.user            = this;
            d.sessionName     = sessionName;
            return m_v4->RegisterMod(&d, &m_mod) == Result::Ok;
        }

        void release()
        {
            if (m_v4 && m_mod) m_v4->UnregisterMod(m_mod);
            m_mod = 0;
            std::lock_guard<std::mutex> lk(m_slotMx);
            m_close.clear();
            m_error.clear();
        }

        /// Create a view. `name` is unique within your mod (used by FindView
        /// and the log lines); `absHtmlPath` is an absolute path to the page
        /// (your mod folder lives under Data\Magelight\<modId>\ — resolve it
        /// from GetModuleFileNameW). Returns 0 on failure (v4()->GetLastErrorMessage
        /// says why).
        ViewId createView(const char* name, const char* absHtmlPath, Layer layer,
                          const ViewOpts& opts = {})
        {
            if (!m_v4 || !m_mod) return 0;
            ViewDesc vd{};
            vd.size        = sizeof(vd);
            vd.name        = name;
            vd.htmlPath    = absHtmlPath;
            vd.anchor      = opts.anchor;
            vd.x           = opts.x;  vd.y = opts.y;
            vd.w           = opts.w;  vd.h = opts.h;
            vd.fullscreen  = opts.fullscreen;
            vd.clickThrough= opts.clickThrough;
            vd.startVisible= opts.startVisible;
            vd.layer       = layer;
            vd.uiScale     = opts.uiScale;
            vd.onDomReady  = opts.onDomReady;
            ViewId id = 0;
            if (m_v4->CreateViewEx(m_mod, &vd, &id) != Result::Ok) return 0;
            if (opts.hibernateMs && m_v4->hostVersionNumber >= 1600)
                m_v4->SetViewHibernate(id, opts.hibernateMs);
            return id;
        }

        /// Called when UI mode LEAVES this view (Escape, its hotkey, a lost
        /// race, a load boundary) — the "the user closed it" signal. Also
        /// fires if the view never got UI mode (UIModeRefused).
        void onClose(ViewId view, std::function<void(ViewId)> fn)
        {
            std::lock_guard<std::mutex> lk(m_slotMx);
            m_close[view] = std::move(fn);
        }
        /// Called when the view's page fails to load (bad path, JS crash on load).
        void onError(ViewId view, std::function<void(ViewId, const char*)> fn)
        {
            std::lock_guard<std::mutex> lk(m_slotMx);
            m_error[view] = std::move(fn);
        }

        // ── Raw access for everything the wrapper does not wrap ──────────────
        const MagelightApi1* v1() const { return m_v1; }
        const MagelightApi4* v4() const { return m_v4; }
        ModId id() const { return m_mod; }
        explicit operator bool() const { return m_mod != 0; }

    private:
        static void dispatch(const EventData* ev, void* user)
        {
            auto* self = static_cast<MagelightMod*>(user);
            if (!self || !ev) return;
            std::function<void(ViewId)> close;
            std::function<void(ViewId, const char*)> error;
            {
                std::lock_guard<std::mutex> lk(self->m_slotMx);
                if (ev->type == Event::UIModeExited || ev->type == Event::UIModeRefused) {
                    if (auto it = self->m_close.find(ev->view); it != self->m_close.end()) close = it->second;
                } else if (ev->type == Event::ViewLoadFailed) {
                    if (auto it = self->m_error.find(ev->view); it != self->m_error.end()) error = it->second;
                }
            }
            if (close) close(ev->view);
            if (error) error(ev->view, ev->detail ? ev->detail : "");
        }

        const MagelightApi1* m_v1 = nullptr;
        const MagelightApi4* m_v4 = nullptr;
        ModId m_mod = 0;
        std::mutex m_slotMx;
        std::map<ViewId, std::function<void(ViewId)>> m_close;
        std::map<ViewId, std::function<void(ViewId, const char*)>> m_error;
    };

}  // namespace MAGELIGHT_API
