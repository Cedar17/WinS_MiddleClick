#include "hook.hpp"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace {

constexpr wchar_t kMutexName[] = L"Local\\WinS_MiddleClick";

void ShowError(const wchar_t* message) {
    MessageBoxW(nullptr, message, L"WinS_MiddleClick", MB_OK | MB_ICONERROR);
}

}  // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    HANDLE mutex = CreateMutexW(nullptr, TRUE, kMutexName);
    if (mutex == nullptr) {
        ShowError(L"Failed to create the single-instance mutex.");
        return 1;
    }

    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        CloseHandle(mutex);
        return 0;
    }

    if (!wins_middle_click::InstallHook()) {
        ShowError(L"Failed to install the low-level keyboard hook.");
        CloseHandle(mutex);
        return 1;
    }

    MSG msg{};
    int result = 0;
    while ((result = static_cast<int>(GetMessageW(&msg, nullptr, 0, 0))) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    wins_middle_click::UninstallHook();
    ReleaseMutex(mutex);
    CloseHandle(mutex);

    return result == -1 ? 1 : 0;
}
