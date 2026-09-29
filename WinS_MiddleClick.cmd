@echo off
setlocal
title Win+S -^> Middle Click

set "WINS_SELF=%~f0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$p=$env:WINS_SELF; ^
$t=[IO.File]::ReadAllText($p); ^
$m='__CS_PAYLOAD_BELOW__'; ^
$i=$t.LastIndexOf($m); ^
if($i -lt 0){throw 'C# payload marker not found'}; ^
$src=$t.Substring($i+$m.Length); ^
Add-Type -TypeDefinition $src; ^
[WinSHook]::Run()"

exit /b


__CS_PAYLOAD_BELOW__
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class WinSHook
{
    private const int WH_KEYBOARD_LL = 13;

    private const int WM_KEYDOWN    = 0x0100;
    private const int WM_KEYUP      = 0x0101;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_SYSKEYUP   = 0x0105;

    private const int VK_S       = 0x53;
    private const int VK_LWIN    = 0x5B;
    private const int VK_RWIN    = 0x5C;

    private const int VK_LSHIFT   = 0xA0;
    private const int VK_RSHIFT   = 0xA1;
    private const int VK_LCONTROL = 0xA2;
    private const int VK_RCONTROL = 0xA3;
    private const int VK_LMENU    = 0xA4;
    private const int VK_RMENU    = 0xA5;

    private const uint LLKHF_INJECTED = 0x10;

    private const uint INPUT_MOUSE    = 0;
    private const uint INPUT_KEYBOARD = 1;

    private const uint KEYEVENTF_KEYUP = 0x0002;

    private const uint MOUSEEVENTF_MIDDLEDOWN = 0x0020;
    private const uint MOUSEEVENTF_MIDDLEUP   = 0x0040;

    private static bool lShift;
    private static bool rShift;
    private static bool lCtrl;
    private static bool rCtrl;
    private static bool lAlt;
    private static bool rAlt;

    private static bool winDeferred;
    private static int deferredWinVK;
    private static bool winSActive;
    private static bool winReplayed;

    private delegate IntPtr LowLevelKeyboardProc(
        int nCode,
        IntPtr wParam,
        IntPtr lParam
    );

    private static readonly LowLevelKeyboardProc Proc = HookCallback;
    private static IntPtr Hook = IntPtr.Zero;

    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int x;
        public int y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public UIntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
        public uint lPrivate;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public INPUTUNION U;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct INPUTUNION
    {
        [FieldOffset(0)]
        public MOUSEINPUT mi;

        [FieldOffset(0)]
        public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(
        int idHook,
        LowLevelKeyboardProc lpfn,
        IntPtr hMod,
        uint dwThreadId
    );

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(
        IntPtr hhk,
        int nCode,
        IntPtr wParam,
        IntPtr lParam
    );

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(
        IntPtr hhk
    );

    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr GetModuleHandle(
        string lpModuleName
    );

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(
        uint nInputs,
        INPUT[] pInputs,
        int cbSize
    );

    [DllImport("user32.dll")]
    private static extern int GetMessage(
        out MSG lpMsg,
        IntPtr hWnd,
        uint wMsgFilterMin,
        uint wMsgFilterMax
    );

    private static bool OtherModifierDown()
    {
        return
            lShift || rShift ||
            lCtrl  || rCtrl  ||
            lAlt   || rAlt;
    }

    private static void UpdateModifier(
        int vk,
        bool down
    )
    {
        switch (vk)
        {
            case VK_LSHIFT:
                lShift = down;
                break;

            case VK_RSHIFT:
                rShift = down;
                break;

            case VK_LCONTROL:
                lCtrl = down;
                break;

            case VK_RCONTROL:
                rCtrl = down;
                break;

            case VK_LMENU:
                lAlt = down;
                break;

            case VK_RMENU:
                rAlt = down;
                break;
        }
    }

    private static void SendKeyboard(
        int vk,
        bool keyUp
    )
    {
        INPUT[] input = new INPUT[1];

        input[0].type = INPUT_KEYBOARD;
        input[0].U.ki.wVk = (ushort)vk;
        input[0].U.ki.wScan = 0;
        input[0].U.ki.dwFlags =
            keyUp ? KEYEVENTF_KEYUP : 0;
        input[0].U.ki.time = 0;
        input[0].U.ki.dwExtraInfo = UIntPtr.Zero;

        SendInput(
            1,
            input,
            Marshal.SizeOf(typeof(INPUT))
        );
    }

    private static void ReplayDeferredWin()
    {
        if (!winDeferred)
            return;

        SendKeyboard(
            deferredWinVK,
            false
        );

        winDeferred = false;
        winReplayed = true;
    }

    private static void SendPlainWinPress()
    {
        int vk = deferredWinVK;

        SendKeyboard(vk, false);
        SendKeyboard(vk, true);

        winDeferred = false;
        winReplayed = false;
        deferredWinVK = 0;
    }

    private static void MiddleClick()
    {
        INPUT[] input = new INPUT[2];

        input[0].type = INPUT_MOUSE;
        input[0].U.mi.dwFlags =
            MOUSEEVENTF_MIDDLEDOWN;

        input[1].type = INPUT_MOUSE;
        input[1].U.mi.dwFlags =
            MOUSEEVENTF_MIDDLEUP;

        SendInput(
            2,
            input,
            Marshal.SizeOf(typeof(INPUT))
        );
    }

    private static IntPtr HookCallback(
        int nCode,
        IntPtr wParam,
        IntPtr lParam
    )
    {
        if (nCode < 0)
        {
            return CallNextHookEx(
                Hook,
                nCode,
                wParam,
                lParam
            );
        }

        KBDLLHOOKSTRUCT info =
            Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(
                lParam
            );

        int msg = wParam.ToInt32();
        int vk  = (int)info.vkCode;

        bool down =
            msg == WM_KEYDOWN ||
            msg == WM_SYSKEYDOWN;

        bool up =
            msg == WM_KEYUP ||
            msg == WM_SYSKEYUP;

        bool injected =
            (info.flags & LLKHF_INJECTED) != 0;

        if (injected)
        {
            return CallNextHookEx(
                Hook,
                nCode,
                wParam,
                lParam
            );
        }

        if (
            vk == VK_LSHIFT ||
            vk == VK_RSHIFT ||
            vk == VK_LCONTROL ||
            vk == VK_RCONTROL ||
            vk == VK_LMENU ||
            vk == VK_RMENU
        )
        {
            if (down)
            {
                if (winDeferred)
                    ReplayDeferredWin();

                UpdateModifier(vk, true);
            }
            else if (up)
            {
                UpdateModifier(vk, false);
            }

            return CallNextHookEx(
                Hook,
                nCode,
                wParam,
                lParam
            );
        }

        if (
            (vk == VK_LWIN ||
             vk == VK_RWIN) &&
            down
        )
        {
            if (OtherModifierDown())
            {
                return CallNextHookEx(
                    Hook,
                    nCode,
                    wParam,
                    lParam
                );
            }

            if (winDeferred)
                return (IntPtr)1;

            winDeferred = true;
            deferredWinVK = vk;
            winReplayed = false;

            return (IntPtr)1;
        }

        if (
            vk == VK_S &&
            down &&
            winDeferred &&
            !OtherModifierDown()
        )
        {
            if (!winSActive)
            {
                winSActive = true;
                MiddleClick();
            }

            return (IntPtr)1;
        }

        if (
            vk == VK_S &&
            up &&
            winSActive
        )
        {
            return (IntPtr)1;
        }

        if (
            down &&
            winDeferred &&
            !winSActive
        )
        {
            ReplayDeferredWin();

            return CallNextHookEx(
                Hook,
                nCode,
                wParam,
                lParam
            );
        }

        if (
            (vk == VK_LWIN ||
             vk == VK_RWIN) &&
            up
        )
        {
            if (winSActive)
            {
                winSActive = false;
                winDeferred = false;
                winReplayed = false;
                deferredWinVK = 0;

                return (IntPtr)1;
            }

            if (winDeferred)
            {
                SendPlainWinPress();
                return (IntPtr)1;
            }

            if (winReplayed)
            {
                winReplayed = false;
                deferredWinVK = 0;

                return CallNextHookEx(
                    Hook,
                    nCode,
                    wParam,
                    lParam
                );
            }
        }

        return CallNextHookEx(
            Hook,
            nCode,
            wParam,
            lParam
        );
    }

    public static void Run()
    {
        bool createdNew;

        using (
            Mutex mutex = new Mutex(
                true,
                "Local\\WinS_MiddleClick",
                out createdNew
            )
        )
        {
            if (!createdNew)
                return;

            using (
                Process process =
                    Process.GetCurrentProcess()
            )
            using (
                ProcessModule module =
                    process.MainModule
            )
            {
                Hook = SetWindowsHookEx(
                    WH_KEYBOARD_LL,
                    Proc,
                    GetModuleHandle(module.ModuleName),
                    0
                );
            }

            if (Hook == IntPtr.Zero)
            {
                Console.WriteLine(
                    "Failed to start."
                );

                Console.WriteLine(
                    "Win32 error: " +
                    Marshal.GetLastWin32Error()
                );

                Console.WriteLine();
                Console.WriteLine(
                    "Press Enter to exit."
                );

                Console.ReadLine();
                return;
            }

            Console.Clear();

            Console.WriteLine(
                "Win+S -> Middle Click"
            );

            Console.WriteLine();
            Console.WriteLine(
                "Running."
            );

            Console.WriteLine(
                "Close this window to exit."
            );

            try
            {
                MSG msg;

                while (
                    GetMessage(
                        out msg,
                        IntPtr.Zero,
                        0,
                        0
                    ) > 0
                )
                {
                }
            }
            finally
            {
                if (Hook != IntPtr.Zero)
                {
                    UnhookWindowsHookEx(Hook);
                    Hook = IntPtr.Zero;
                }
            }
        }
    }
}