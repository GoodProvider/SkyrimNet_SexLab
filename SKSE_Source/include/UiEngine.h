#pragma once

#include <cstdint>
#include <functional>
#include <string_view>

#include "PrismaUI_API.h"

/// UI engine adapter: prefers Magelight (Data\Magelight, host v4 API >= 0.30.1), falls back to
/// PrismaUI (Data\PrismaUI). Both hosts are optional; with neither present every call is a no-op.
/// Views created here own their bridge pages (window.onXxx globals) which are engine-identical,
/// so the same HTML ships under both Data trees (repo root PrismaUI/ and Magelight/).
namespace UiEngine {

enum class Kind : std::uint8_t { None = 0, Prisma = 1, Magelight = 2 };

using JsListenerBody = void (*)(const char* argument);

/// Acquire the preferred host (Magelight v4 + RegisterMod) else PrismaUI v1. Idempotent; safe
/// to call from any thread. The chosen engine is logged once.
void Init();
Kind GetKind();
bool Available();

/// Raw PrismaUI v1 interface; non-null only when the kind is Prisma. Exposed for WebUI.cpp's
/// foreign-view bookkeeping (PrismaUI.log parsing), which has no Magelight equivalent.
PRISMA_UI_API::IVPrismaUI1* GetRawPrisma();

/// WebUI overlay view (index.html). Returns false when the engine has no host or the page
/// was not found — callers then keep their existing critical-log paths.
bool CreateWebUIView(void (*onDomReady)());
/// Scene HUD view (hud.html): never takes UI mode / focus, matching the old Focus-less HUD.
bool CreateHudView(void (*onDomReady)());

bool IsValid();      // webui view
bool IsHidden();     // webui view
void Show();         // webui view; Magelight also requests UI mode (pause)
void Hide();         // webui view; Magelight releases UI mode first
bool HasFocus();     // webui view
bool AnyActiveFocus();  // some view of OUR engine holds focus / UI mode
/// JS → pause toggle: Prisma re-focuses from scratch; Magelight retargets the live UI mode in place.
void SetPaused(bool paused);

void InvokeJS(const char* script);                     // webui view (queued by caller until domReady)
void RegisterListener(std::string_view name, JsListenerBody body);  // webui view

bool HudIsValid();
bool HudIsHidden();
void HudShow();
void HudHide();
void HudInvokeJS(const char* script);

}  // namespace UiEngine
