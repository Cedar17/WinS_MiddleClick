#include "hook.hpp"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace wins_middle_click {
namespace {

constexpr int kWhKeyboardLl = 13;
constexpr DWORD kLlkfInjected = 0x10;

HHOOK g_hook = nullptr;

bool g_lShift = false;
bool g_rShift = false;
bool g_lCtrl = false;
bool g_rCtrl = false;
bool g_lAlt = false;
bool g_rAlt = false;

bool g_winDeferred = false;
int g_deferredWinVk = 0;
bool g_winSActive = false;
bool g_winReplayed = false;

bool OtherModifierDown() {
    return g_lShift || g_rShift || g_lCtrl || g_rCtrl || g_lAlt || g_rAlt;
}

void UpdateModifier(int vk, bool down) {
    switch (vk) {
        case VK_LSHIFT:   g_lShift = down; break;
        case VK_RSHIFT:   g_rShift = down; break;
        case VK_LCONTROL: g_lCtrl = down; break;
        case VK_RCONTROL: g_rCtrl = down; break;
        case VK_LMENU:    g_lAlt = down; break;
        case VK_RMENU:    g_rAlt = down; break;
        default: break;
    }
}

void SendKeyboard(int vk, bool keyUp) {
    INPUT input{};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = static_cast<WORD>(vk);
    input.ki.dwFlags = keyUp ? KEYEVENTF_KEYUP : 0;
    SendInput(1, &input, sizeof(INPUT));
}

void ReplayDeferredWin() {
    if (!g_winDeferred) {
        return;
    }

    SendKeyboard(g_deferredWinVk, false);
    g_winDeferred = false;
    g_winReplayed = true;
}

void SendPlainWinPress() {
    const int vk = g_deferredWinVk;
    SendKeyboard(vk, false);
    SendKeyboard(vk, true);

    g_winDeferred = false;
    g_winReplayed = false;
    g_deferredWinVk = 0;
}

void MiddleClick() {
    INPUT input[2]{};
    input[0].type = INPUT_MOUSE;
    input[0].mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN;
    input[1].type = INPUT_MOUSE;
    input[1].mi.dwFlags = MOUSEEVENTF_MIDDLEUP;
    SendInput(2, input, sizeof(INPUT));
}

LRESULT CALLBACK HookCallback(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode < 0) {
        return CallNextHookEx(g_hook, nCode, wParam, lParam);
    }

    const auto* info = reinterpret_cast<const KBDLLHOOKSTRUCT*>(lParam);
    const int vk = static_cast<int>(info->vkCode);
    const bool down = wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN;
    const bool up = wParam == WM_KEYUP || wParam == WM_SYSKEYUP;
    const bool injected = (info->flags & kLlkfInjected) != 0;

    if (injected) {
        return CallNextHookEx(g_hook, nCode, wParam, lParam);
    }

    if (vk == VK_LSHIFT || vk == VK_RSHIFT ||
        vk == VK_LCONTROL || vk == VK_RCONTROL ||
        vk == VK_LMENU || vk == VK_RMENU) {
        if (down) {
            if (g_winDeferred) {
                ReplayDeferredWin();
            }
            UpdateModifier(vk, true);
        } else if (up) {
            UpdateModifier(vk, false);
        }
        return CallNextHookEx(g_hook, nCode, wParam, lParam);
    }

    if ((vk == VK_LWIN || vk == VK_RWIN) && down) {
        if (OtherModifierDown()) {
            return CallNextHookEx(g_hook, nCode, wParam, lParam);
        }
        if (g_winDeferred) {
            return 1;
        }

        g_winDeferred = true;
        g_deferredWinVk = vk;
        g_winReplayed = false;
        return 1;
    }

    if (vk == 'S' && down && g_winDeferred && !OtherModifierDown()) {
        if (!g_winSActive) {
            g_winSActive = true;
            MiddleClick();
        }
        return 1;
    }

    if (vk == 'S' && up && g_winSActive) {
        return 1;
    }

    if (down && g_winDeferred && !g_winSActive) {
        ReplayDeferredWin();
        return CallNextHookEx(g_hook, nCode, wParam, lParam);
    }

    if ((vk == VK_LWIN || vk == VK_RWIN) && up) {
        if (g_winSActive) {
            g_winSActive = false;
            g_winDeferred = false;
            g_winReplayed = false;
            g_deferredWinVk = 0;
            return 1;
        }

        if (g_winDeferred) {
            SendPlainWinPress();
            return 1;
        }

        if (g_winReplayed) {
            g_winReplayed = false;
            g_deferredWinVk = 0;
            return CallNextHookEx(g_hook, nCode, wParam, lParam);
        }
    }

    return CallNextHookEx(g_hook, nCode, wParam, lParam);
}

}  // namespace

bool InstallHook() {
    if (g_hook != nullptr) {
        return true;
    }

    g_hook = SetWindowsHookExW(
        kWhKeyboardLl,
        HookCallback,
        GetModuleHandleW(nullptr),
        0);
    return g_hook != nullptr;
}

void UninstallHook() {
    if (g_hook != nullptr) {
        UnhookWindowsHookEx(g_hook);
        g_hook = nullptr;
    }
}

}  // namespace wins_middle_click
