#include "UiEngine.h"

#include <Windows.h>

#include <atomic>
#include <filesystem>
#include <mutex>
#include <string>
#include <utility>

#include "MagelightUI_API.h"
#include "PrismaUI_API.h"
#include "WebUI_Log.h"

namespace UiEngine {

namespace {

using namespace MAGELIGHT_API;

constexpr const char* kModId = "SkyrimNet_SexLab";
// PostGameTask (>= 0.30.1) is the render→game marshalling primitive, and its gate also covers
// the 0.26.11 in-place UI-mode retarget used by SetPaused.
constexpr std::uint32_t kMinHostVersion = PackVersion(0, 30, 1);

// Both engines read the SAME views folder: Data/PrismaUI/views/SkyrimNet_SexLab/. Prisma resolves it
// relative to its runtime dir (the short "SkyrimNet_SexLab/<file>.html" form); Magelight takes an
// absolute path (its header documents drive-letter paths). Absolute keeps the two on one shipped tree.
static const std::filesystem::path& SharedViewsDir()
{
    static const std::filesystem::path dir = [] {
        // CWD is the install root when Steam/launcher starts Skyrim from there. Do NOT anchor on
        // SKSE::log::log_directory(): it's user-redirectable (e.g. to Documents) and breaks this path.
        std::error_code ec;
        return std::filesystem::current_path(ec) / "Data" / "PrismaUI" / "views" / kModId;
    }();
    return dir;
}

static std::string SharedViewPath(const char* file) { return (SharedViewsDir() / file).string(); }

static Kind g_kind{Kind::None};
static PRISMA_UI_API::IVPrismaUI1* g_prisma = nullptr;
static const MagelightApi4* g_ml = nullptr;
static ModId g_mod = 0;
// One handle slot per view: PrismaView and ViewId are both uint64_t.
static std::atomic<PrismaView> g_view{0};
static std::atomic<PrismaView> g_hudView{0};

// Dom-ready trampoline slots: the C function pointer handed to the host posts these to the game thread.
static void (*g_webuiDomCb)() = nullptr;
static void (*g_hudDomCb)() = nullptr;

void WebUiMagelightDomReady(MAGELIGHT_API::ViewId)
{
    if (!g_ml || !g_mod) return;
    g_ml->PostGameTask([](void* user) {
        auto cb = static_cast<void (*)()>(user);
        if (cb)
            cb();
    }, g_webuiDomCb);
}

void HudMagelightDomReady(MAGELIGHT_API::ViewId)
{
    if (!g_ml || !g_mod) return;
    g_ml->PostGameTask([](void* user) {
        auto cb = static_cast<void (*)()>(user);
        if (cb)
            cb();
    }, g_hudDomCb);
}

// Render thread: the argument is valid for the call only — copy it, then run the body on the game thread.
void MagelightListener(MAGELIGHT_API::ViewId, const char* argument, void* user)
{
    if (!g_ml || !g_mod) return;  // host gone mid-frame: drop the event
    auto pair = new std::pair<JsListenerBody, std::string>(static_cast<JsListenerBody>(user),
                                                           argument ? argument : "");
    g_ml->PostGameTask([](void* p) {
        auto* pr = static_cast<std::pair<JsListenerBody, std::string>*>(p);
        if (pr->first)
            pr->first(pr->second.c_str());
        delete pr;
    }, pair);
}

bool MagelightCreate(const char* name, const char* htmlPath, bool hud)
{
    // The dom-ready trampoline (WebUiMagelightDomReady / HudMagelightDomReady) posts the caller's
    // onDomReady slot to the game thread; it is set before CreateViewEx fires it.
    ViewDesc desc{};
    desc.size = sizeof(ViewDesc);
    desc.name = name;
    // Absolute path into the shared views folder (both engines read PrismaUI/views/SkyrimNet_SexLab/).
    desc.htmlPath = htmlPath;
    desc.fullscreen = true;
    desc.clickThrough = hud;  // HUD: never receives input, matching the old Focus-less Prisma view
    desc.startVisible = false;
    desc.layer = hud ? Layer::Hud : Layer::Panel;
    desc.uiScale = 0.0f;
    desc.onDomReady = hud ? HudMagelightDomReady : WebUiMagelightDomReady;
    ViewId out = 0;
    const auto r = g_ml->CreateViewEx(g_mod, &desc, &out);
    if (r != Result::Ok || !out) {
        std::string msg = g_ml->GetLastErrorMessage(g_mod);
        webui_log::critical("UiEngine: CreateViewEx({}) -> {} ({})", name, static_cast<int>(r), msg.c_str());
        return false;
    }
    if (hud)
        g_hudView.store(out);
    else
        g_view.store(out);
    return true;
}

void PrismaDomReadyWebui(PrismaView view)
{
    if (view)
        g_view.store(view);  // the real id only exists once creation lands
    auto cb = g_webuiDomCb;
    if (cb)
        cb();
}

void PrismaDomReadyHud(PrismaView view)
{
    if (view)
        g_hudView.store(view);
    auto cb = g_hudDomCb;
    if (cb)
        cb();
}

}  // namespace

void Init()
{
    static std::once_flag flag;
    std::call_once(flag, [] {
        if (auto* api = RequestApi4()) {
            ModDesc desc{};
            desc.size = sizeof(ModDesc);
            desc.modId = kModId;
            desc.displayName = "SkyrimNet_SexLab";
            desc.minHostVersion = kMinHostVersion;
            desc.callbackThread = CallbackThread::GameThread;
            const auto r = api->RegisterMod(&desc, &g_mod);
            if (r == Result::Ok && g_mod) {
                g_ml = api;
                g_kind = Kind::Magelight;
                webui_log::info("UiEngine: Magelight host v{} selected.", api->hostVersionNumber);
                // Pages are file-only by default, but both fetch the Dashboard ui_scale from SkyrimNet's
                // local server. Applies on a page's next load, so set it before any view exists.
                const auto policy = api->SetNetworkPolicy(g_mod, NetworkPolicy::LoopbackOnly);
                if (policy != Result::Ok) {
                    std::string msg = api->GetLastErrorMessage(g_mod);
                    webui_log::warn("UiEngine: SetNetworkPolicy -> {} ({}), Dashboard ui_scale will not load.",
                                    static_cast<int>(policy), msg.c_str());
                }
                return;
            }
            std::string msg = api->GetLastErrorMessage(0);
            webui_log::warn("UiEngine: RegisterMod -> {} ({}), falling back to PrismaUI.",
                            static_cast<int>(r), msg.c_str());
        }
        if (auto* prisma = static_cast<PRISMA_UI_API::IVPrismaUI1*>(
                PRISMA_UI_API::RequestPluginAPI(PRISMA_UI_API::InterfaceVersion::V1))) {
            g_prisma = prisma;
            g_kind = Kind::Prisma;
            webui_log::info("UiEngine: PrismaUI fallback selected.");
        } else {
            webui_log::critical("UiEngine: neither Magelight nor PrismaUI available.");
        }
    });
}

Kind GetKind() { return g_kind; }

bool Available() { return g_kind != Kind::None; }

PRISMA_UI_API::IVPrismaUI1* GetRawPrisma() { return g_prisma; }

bool CreateWebUIView(void (*onDomReady)())
{
    Init();
    if (g_ml && g_mod) {
        g_webuiDomCb = onDomReady;
        const std::string path = SharedViewPath("index.html");  // named local: valid for the synchronous call
        return MagelightCreate("index", path.c_str(), false);
    }
    if (g_prisma) {
        // Resolves under Data/PrismaUI/views/, not SKSE/Plugins/. The id returned by CreateView is
        // valid immediately — store it so RegisterListener works before DomReady fires.
        g_webuiDomCb = onDomReady;
        const auto v = g_prisma->CreateView("SkyrimNet_SexLab/index.html", PrismaDomReadyWebui);
        if (v)
            g_view.store(v);
        return g_prisma->IsValid(v);
    }
    return false;
}

bool CreateHudView(void (*onDomReady)())
{
    Init();
    if (g_ml && g_mod) {
        g_hudDomCb = onDomReady;
        const std::string path = SharedViewPath("hud.html");  // named local: valid for the synchronous call
        return MagelightCreate("hud", path.c_str(), true);
    }
    if (g_prisma) {
        // Resolves under Data/PrismaUI/views/.
        g_hudDomCb = onDomReady;
        g_hudView.store(g_prisma->CreateView("SkyrimNet_SexLab/hud.html", PrismaDomReadyHud));
        return g_prisma->IsValid(g_hudView.load());
    }
    return false;
}

bool IsValid()
{
    if (g_kind == Kind::None) return false;
    const auto v = g_view.load();
    if (v == 0) return false;
    if (g_ml) return g_ml->IsViewValid(v);
    return g_prisma->IsValid(v);
}

bool IsHidden()
{
    const auto v = g_view.load();
    if (g_kind == Kind::None || !v) return true;
    if (g_ml) {
        ViewDesc desc{};
        desc.size = sizeof(ViewDesc);
        if (g_ml->GetViewInfo(v, &desc) != Result::Ok)
            return true;  // gone view: treat as hidden so callers no-op
        return !desc.startVisible;  // startVisible doubles as the current-visibility flag in v4
    }
    return g_prisma->IsHidden(v);
}

void Show()
{
    auto v = g_view.load();
    if (!v || !Available()) return;
    if (g_ml) {
        g_ml->ShowView(v, true);
        const auto r = g_ml->RequestUIMode(v, kUIModeFlagPause);
        if (r != Result::Ok)
            webui_log::warn("UiEngine: Show RequestUIMode -> {}", static_cast<int>(r));
    } else {
        g_prisma->Show(v);
        g_prisma->Focus(v, true);
    }
}

void Hide()
{
    auto v = g_view.load();
    if (!v || !Available()) return;
    if (g_ml) {
        g_ml->ReleaseUIMode(g_mod);  // no-op unless we own it; never hides the view
        g_ml->ShowView(v, false);
    } else {
        g_prisma->Unfocus(v);
        g_prisma->Hide(v);
    }
}

void LogViewLayout(const char* reason)
{
    const char* why = reason ? reason : "";
    const auto v = g_view.load();
    if (g_ml) {
        std::int32_t dw = 0, dh = 0;
        if (g_ml->GetDisplaySize)
            g_ml->GetDisplaySize(&dw, &dh);
        const int vr = g_ml->QueryCapability ? g_ml->QueryCapability("vr") : -1;
        webui_log::info("[UI layout] {} engine=Magelight host={} vr={} display={}x{} view={}", why,
                        g_ml->hostVersionNumber, vr, dw, dh, static_cast<std::uint64_t>(v));
        if (!v)
            return;
        ViewDesc desc{};
        desc.size = sizeof(ViewDesc);
        if (g_ml->GetViewInfo(v, &desc) == Result::Ok) {
            webui_log::info("[UI layout] {} view fullscreen={} rect={},{} {}x{} anchor={} uiScale={} layer={} visible={}",
                            why, desc.fullscreen, desc.x, desc.y, desc.w, desc.h, static_cast<int>(desc.anchor),
                            desc.uiScale, static_cast<int>(desc.layer), desc.startVisible);
        } else {
            webui_log::info("[UI layout] {} GetViewInfo failed: {}", why, g_ml->GetLastErrorMessage(g_mod));
        }
        if (vr == 1 && g_ml->hostVersionNumber >= 1800 && g_ml->GetViewVRPlacement) {
            VRPlacementDesc pl{};
            pl.size = sizeof(VRPlacementDesc);
            if (g_ml->GetViewVRPlacement(v, &pl) == Result::Ok) {
                webui_log::info("[UI layout] {} VR placement mode={} distance={}m width={}m heightOffset={}m", why,
                                static_cast<int>(pl.mode), pl.distanceMeters, pl.widthMeters, pl.heightOffset);
            } else {
                webui_log::info("[UI layout] {} GetViewVRPlacement failed: {}", why, g_ml->GetLastErrorMessage(g_mod));
            }
        }
        return;
    }
    if (g_prisma) {
        webui_log::info("[UI layout] {} engine=PrismaUI view={} valid={} hidden={}", why,
                        static_cast<std::uint64_t>(v), v ? g_prisma->IsValid(v) : false,
                        v ? g_prisma->IsHidden(v) : true);
        return;
    }
    webui_log::info("[UI layout] {} engine=none", why);
}

bool HasFocus()
{
    if (g_kind == Kind::None) return false;
    const auto v = g_view.load();
    if (v == 0) return false;
    if (g_ml) return g_mod && g_ml->GetUIModeOwner() == g_mod;
    return g_prisma->HasFocus(v);
}

bool AnyActiveFocus()
{
    if (g_kind == Kind::None) return false;
    if (g_ml) return g_ml->IsUIModeActive();
    return g_prisma->HasAnyActiveFocus();
}

void SetPaused(bool paused)
{
    auto v = g_view.load();
    if (!v || !Available()) return;
    if (g_ml) {
        // 0.26.11+: re-requesting on the live UI-mode view retargets kUIModeFlagPause in place,
        // replacing the old Unfocus+Focus-from-scratch dance.
        const auto r = g_ml->RequestUIMode(v, paused ? kUIModeFlagPause : kUIModeFlagNone);
        if (r != Result::Ok)
            webui_log::warn("UiEngine: SetPaused({}) -> {}", paused, static_cast<int>(r));
    } else {
        // A repeat Focus while already focused does not change the pause state; re-focus from scratch.
        g_prisma->Unfocus(v);
        const bool ok = g_prisma->Focus(v, paused);
        webui_log::info("UiEngine: PrismaUI Focus(pause={}) ok={} hasFocus={}", paused, ok,
                        g_prisma->HasFocus(v));
    }
}

namespace {

std::uint32_t VrButtonCode(std::string_view name)
{
    if (name == "a") return kVRButtonA;
    if (name == "stick") return kVRButtonStickClick;
    if (name == "trigger") return kVRButtonTrigger;
    if (name == "touchpad") return kVRButtonTouchpad;
    if (name == "grip") return kVRButtonGrip;
    return kVRButtonNone;
}

// Present thread: hand the body to the game thread.
void OnVrChord(ViewId, void* user)
{
    if (!g_ml || !g_mod || !user) return;
    g_ml->PostGameTask([](void* p) {
        auto body = reinterpret_cast<void (*)()>(p);
        if (body)
            body();
    }, user);
}

}  // namespace

bool BindVrChord(std::string_view button, std::string_view modifier, std::string_view hand, void (*body)())
{
    const auto v = g_view.load();
    if (!g_ml || !g_mod || !v) return false;
    // BindVRHotkeyCallback arrived in 0.21.0 (below our 0.30.1 floor); "vr" is 1 only while the presenter is live.
    if (g_ml->hostVersionNumber < 2100 || g_ml->QueryCapability("vr") != 1) {
        webui_log::info("UiEngine: not VR, controller chord skipped.");
        return false;
    }
    VRHotkeyDesc desc{};
    desc.size = sizeof(VRHotkeyDesc);
    desc.button = body ? VrButtonCode(button) : kVRButtonNone;
    desc.modifier = VrButtonCode(modifier);
    if (desc.modifier == desc.button)
        desc.modifier = kVRButtonNone;
    desc.hand = hand == "left" ? 1 : hand == "right" ? 2 : 0;
    const auto r = g_ml->BindVRHotkeyCallback(v, &desc, desc.button ? OnVrChord : nullptr,
                                              reinterpret_cast<void*>(body));
    if (r != Result::Ok) {
        std::string msg = g_ml->GetLastErrorMessage(g_mod);
        webui_log::warn("UiEngine: BindVRHotkeyCallback -> {} ({})", static_cast<int>(r), msg.c_str());
        return false;
    }
    if (desc.button)
        webui_log::info("UiEngine: VR controller chord bound: {}+{} ({})", button,
                        desc.modifier ? modifier : std::string_view{"none"}, hand);
    else
        webui_log::info("UiEngine: VR controller chord cleared.");
    return true;
}

void InvokeJS(const char* script)
{
    if (!script || !Available()) return;
    const auto v = g_view.load();
    if (v == 0) return;
    if (g_ml)
        g_ml->InvokeJS(v, script);
    else
        g_prisma->Invoke(v, script);
}

void RegisterListener(std::string_view name, JsListenerBody body)
{
    if (!Available() || !body) return;
    const auto v = g_view.load();
    if (v == 0) return;
    if (g_ml) {
        const auto r = g_ml->RegisterJSListenerEx(v, name.data(), MagelightListener, static_cast<void*>(body));
        if (r != Result::Ok)
            webui_log::warn("UiEngine: RegisterJSListenerEx({}) -> {}", name.data(), static_cast<int>(r));
    } else {
        g_prisma->RegisterJSListener(v, name.data(), body);
    }
}

bool HudIsValid()
{
    const auto v = g_hudView.load();
    if (g_kind == Kind::None || !v) return false;
    if (g_ml) return g_ml->IsViewValid(v);
    return g_prisma->IsValid(v);
}

bool HudIsHidden()
{
    const auto v = g_hudView.load();
    if (g_kind == Kind::None || !v) return true;
    if (g_ml) {
        ViewDesc desc{};
        desc.size = sizeof(ViewDesc);
        if (g_ml->GetViewInfo(v, &desc) != Result::Ok)
            return true;  // gone view: treat as hidden so callers no-op
        return !desc.startVisible;  // startVisible doubles as the current-visibility flag in v4
    }
    return g_prisma->IsHidden(v);
}

void HudShow()
{
    const auto v = g_hudView.load();
    if (!Available() || !v) return;
    if (g_ml)
        g_ml->ShowView(v, true);
    else
        g_prisma->Show(v);  // no Focus: the HUD never takes focus
}

void HudHide()
{
    const auto v = g_hudView.load();
    if (!Available() || !v) return;
    if (g_ml)
        g_ml->ShowView(v, false);
    else
        g_prisma->Hide(v);
}

void HudInvokeJS(const char* script)
{
    const auto v = g_hudView.load();
    if (!script || !Available() || !v) return;
    if (g_ml)
        g_ml->InvokeJS(v, script);
    else
        g_prisma->Invoke(v, script);
}

}  // namespace UiEngine
