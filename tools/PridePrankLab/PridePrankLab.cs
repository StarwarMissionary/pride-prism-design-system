using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace PridePrankLab
{
    internal static class Native
    {
        internal const int GWL_EXSTYLE = -20;
        internal const int WS_EX_TRANSPARENT = 0x00000020;
        internal const int WS_EX_TOOLWINDOW = 0x00000080;
        internal const int WS_EX_NOACTIVATE = 0x08000000;
        internal const uint SWP_NOSIZE = 0x0001;
        internal const uint SWP_NOMOVE = 0x0002;
        internal const uint SWP_NOACTIVATE = 0x0010;
        internal const uint SWP_SHOWWINDOW = 0x0040;
        internal static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);

        internal delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        internal struct RECT
        {
            internal int Left;
            internal int Top;
            internal int Right;
            internal int Bottom;
        }

        [DllImport("user32.dll")]
        internal static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll")]
        internal static extern bool IsWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        internal static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        internal static extern bool IsIconic(IntPtr hWnd);

        [DllImport("user32.dll")]
        internal static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

        [DllImport("user32.dll")]
        internal static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        internal static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

        [DllImport("user32.dll")]
        internal static extern int GetWindowTextLength(IntPtr hWnd);

        [DllImport("user32.dll")]
        internal static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        internal static extern bool SetWindowPos(IntPtr hWnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);

        [DllImport("user32.dll")]
        internal static extern bool SetProcessDPIAware();

        [DllImport("dwmapi.dll")]
        private static extern int DwmGetWindowAttribute(IntPtr hWnd, int attribute, out int value, int valueSize);

        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hWnd, int attribute, ref int value, int valueSize);

        private sealed class Candidate
        {
            internal IntPtr Handle;
            internal string Title;
            internal long Score;
        }

        internal static string GetTitle(IntPtr hWnd)
        {
            int length = GetWindowTextLength(hWnd);
            StringBuilder text = new StringBuilder(Math.Max(1, length + 1));
            GetWindowText(hWnd, text, text.Capacity);
            return text.ToString();
        }

        private static bool IsCloaked(IntPtr hWnd)
        {
            int value;
            try
            {
                return DwmGetWindowAttribute(hWnd, 14, out value, sizeof(int)) == 0 && value != 0;
            }
            catch
            {
                return false;
            }
        }

        private static string GetProcessName(IntPtr hWnd)
        {
            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            try
            {
                return Process.GetProcessById((int)processId).ProcessName ?? string.Empty;
            }
            catch { return string.Empty; }
        }

        private static bool Contains(string text, string value)
        {
            return text.IndexOf(value, StringComparison.OrdinalIgnoreCase) >= 0;
        }

        internal static bool IsTargetWindow(IntPtr hWnd, string target)
        {
            if (hWnd == IntPtr.Zero || !IsWindow(hWnd)) return false;
            string processName = GetProcessName(hWnd);
            string title = GetTitle(hWnd);

            bool chat = processName.Equals("ChatGPT", StringComparison.OrdinalIgnoreCase) ||
                        processName.Equals("Codex", StringComparison.OrdinalIgnoreCase) ||
                        Contains(title, "ChatGPT") || Contains(title, "Codex");
            bool discord = processName.Equals("Discord", StringComparison.OrdinalIgnoreCase) || Contains(title, "Discord");
            bool chrome = processName.Equals("chrome", StringComparison.OrdinalIgnoreCase) || Contains(title, "Google Chrome");
            bool steam = processName.Equals("steam", StringComparison.OrdinalIgnoreCase) ||
                         processName.Equals("steamwebhelper", StringComparison.OrdinalIgnoreCase) || Contains(title, "Steam");

            if (target == "ChatGPT / Codex") return chat;
            if (target == "Discord") return discord;
            if (target == "Google Chrome") return chrome;
            if (target == "Steam") return steam;
            return chat || discord || chrome || steam;
        }

        internal static void ApplyPrideAccent(IntPtr hWnd, Color color)
        {
            if (hWnd == IntPtr.Zero || !IsWindow(hWnd)) return;
            int colorRef = color.R | (color.G << 8) | (color.B << 16);
            int luminance = (color.R * 299 + color.G * 587 + color.B * 114) / 1000;
            int textRef = luminance < 145 ? 0x00FFFFFF : 0x00000000;
            try
            {
                DwmSetWindowAttribute(hWnd, 34, ref colorRef, sizeof(int));
                DwmSetWindowAttribute(hWnd, 35, ref colorRef, sizeof(int));
                DwmSetWindowAttribute(hWnd, 36, ref textRef, sizeof(int));
            }
            catch { }
        }

        internal static void ResetPrideAccent(IntPtr hWnd)
        {
            if (hWnd == IntPtr.Zero || !IsWindow(hWnd)) return;
            int defaultColor = unchecked((int)0xFFFFFFFF);
            try
            {
                DwmSetWindowAttribute(hWnd, 34, ref defaultColor, sizeof(int));
                DwmSetWindowAttribute(hWnd, 35, ref defaultColor, sizeof(int));
                DwmSetWindowAttribute(hWnd, 36, ref defaultColor, sizeof(int));
            }
            catch { }
        }

        internal static IntPtr FindBestTargetWindow(string target, IntPtr controlHandle, IntPtr overlayHandle, out string title)
        {
            List<Candidate> candidates = new List<Candidate>();
            IntPtr foreground = GetForegroundWindow();
            EnumWindowsProc callback = delegate(IntPtr hWnd, IntPtr lParam)
            {
                if (hWnd == controlHandle || hWnd == overlayHandle || !IsWindowVisible(hWnd) || IsIconic(hWnd) || IsCloaked(hWnd))
                    return true;

                RECT rect;
                if (!GetWindowRect(hWnd, out rect)) return true;
                int width = rect.Right - rect.Left;
                int height = rect.Bottom - rect.Top;
                if (width < 420 || height < 300) return true;

                string windowTitle = GetTitle(hWnd);
                if (!IsTargetWindow(hWnd, target)) return true;

                long area = (long)width * (long)height;
                long score = area + (hWnd == foreground ? 50000000000L : 0L);
                candidates.Add(new Candidate { Handle = hWnd, Title = windowTitle, Score = score });
                return true;
            };

            EnumWindows(callback, IntPtr.Zero);
            Candidate best = null;
            foreach (Candidate candidate in candidates)
            {
                if (best == null || candidate.Score > best.Score) best = candidate;
            }

            title = best == null ? string.Empty : best.Title;
            return best == null ? IntPtr.Zero : best.Handle;
        }
    }

    internal sealed class PridePalette
    {
        internal string Name;
        internal Color[] Colors;

        internal PridePalette(string name, params string[] hexColors)
        {
            Name = name;
            Colors = new Color[hexColors.Length];
            for (int i = 0; i < hexColors.Length; i++) Colors[i] = ColorTranslator.FromHtml(hexColors[i]);
        }

        public override string ToString() { return Name; }
    }

    internal sealed class Particle
    {
        internal float X;
        internal float Y;
        internal float VelocityX;
        internal float VelocityY;
        internal float Gravity;
        internal float Size;
        internal float Angle;
        internal float Spin;
        internal Color Color;
        internal bool Round;
        internal bool Burst;
    }

    internal sealed class OverlayForm : Form
    {
        private readonly ControlForm controller;
        private readonly System.Windows.Forms.Timer animationTimer;
        private readonly Random random = new Random();
        private readonly List<Particle> particles = new List<Particle>();
        private readonly Stopwatch clock = Stopwatch.StartNew();
        private readonly Color transparentKey = Color.FromArgb(1, 2, 3);
        private IntPtr targetHandle = IntPtr.Zero;
        private IntPtr accentedHandle = IntPtr.Zero;
        private string targetTitle = string.Empty;
        private int tickCounter;
        private DateTime burstUntil = DateTime.MinValue;

        internal bool MasterEnabled = true;
        internal bool RainbowBorderEnabled = true;
        internal bool ConfettiEnabled;
        internal bool BannerEnabled;
        internal bool DiscoEnabled;
        internal bool NativeAccentEnabled = true;
        internal bool PinWhenInactive;
        internal int Intensity = 35;
        internal string BannerText = "HAPPY PRIDE!  LOVE WINS";
        internal string TargetApp = "Auto (active supported app)";
        internal PridePalette Palette;

        internal OverlayForm(ControlForm owner)
        {
            controller = owner;
            Palette = ControlForm.Palettes[0];
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            BackColor = transparentKey;
            TransparencyKey = transparentKey;
            StartPosition = FormStartPosition.Manual;
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer, true);

            animationTimer = new System.Windows.Forms.Timer();
            animationTimer.Interval = 33;
            animationTimer.Tick += AnimationTick;
            animationTimer.Start();
        }

        protected override bool ShowWithoutActivation { get { return true; } }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams parameters = base.CreateParams;
                parameters.ExStyle |= Native.WS_EX_TRANSPARENT | Native.WS_EX_TOOLWINDOW | Native.WS_EX_NOACTIVATE;
                return parameters;
            }
        }

        internal void TriggerBurst(int seconds)
        {
            burstUntil = DateTime.UtcNow.AddSeconds(seconds);
            int count = 90 + Intensity;
            for (int i = 0; i < count; i++) particles.Add(NewParticle(true));
            MasterEnabled = true;
            if (!Visible) ReacquireAndPlace(true);
        }

        internal void RefreshTarget()
        {
            if (accentedHandle != IntPtr.Zero) Native.ResetPrideAccent(accentedHandle);
            accentedHandle = IntPtr.Zero;
            targetHandle = IntPtr.Zero;
            ReacquireAndPlace(true);
        }

        private void AnimationTick(object sender, EventArgs e)
        {
            tickCounter++;
            IntPtr foreground = Native.GetForegroundWindow();
            bool autoSwitch = TargetApp == "Auto (active supported app)" &&
                              foreground != controller.Handle && foreground != Handle &&
                              foreground != targetHandle && Native.IsTargetWindow(foreground, TargetApp);
            int refreshInterval = TargetApp == "Auto (active supported app)" ? 15 : 60;
            if (targetHandle == IntPtr.Zero || !Native.IsWindow(targetHandle) || autoSwitch || tickCounter % refreshInterval == 0)
                ReacquireAndPlace(false);
            else
                PlaceOverTarget();

            UpdateParticles();
            if (Visible) Invalidate();
        }

        private void ReacquireAndPlace(bool forceStatus)
        {
            IntPtr previousHandle = targetHandle;
            targetHandle = Native.FindBestTargetWindow(TargetApp, controller.Handle, Handle, out targetTitle);
            if (previousHandle != IntPtr.Zero && previousHandle != targetHandle)
            {
                Native.ResetPrideAccent(previousHandle);
                if (accentedHandle == previousHandle) accentedHandle = IntPtr.Zero;
            }
            if (targetHandle == IntPtr.Zero)
            {
                if (Visible) Hide();
                if (forceStatus || tickCounter % 60 == 0) controller.SetTargetStatus(false, "Waiting for: " + TargetApp);
                return;
            }

            string label = string.IsNullOrWhiteSpace(targetTitle) ? TargetApp : targetTitle;
            controller.SetTargetStatus(true, "Attached to: " + label);
            PlaceOverTarget();
        }

        private void PlaceOverTarget()
        {
            if (targetHandle == IntPtr.Zero || !Native.IsWindow(targetHandle) || Native.IsIconic(targetHandle))
            {
                if (Visible) Hide();
                return;
            }

            Native.RECT rect;
            if (!Native.GetWindowRect(targetHandle, out rect)) return;
            int width = rect.Right - rect.Left;
            int height = rect.Bottom - rect.Top;
            if (width < 50 || height < 50) return;

            IntPtr foreground = Native.GetForegroundWindow();
            bool targetIsActive = foreground == targetHandle || Native.IsTargetWindow(foreground, TargetApp);
            bool labIsActive = foreground == controller.Handle;
            bool shouldShow = MasterEnabled && (PinWhenInactive || targetIsActive || labIsActive);

            if (MasterEnabled && NativeAccentEnabled && tickCounter % 5 == 0)
            {
                int colorIndex = (int)(clock.ElapsedMilliseconds / 5000L) % Palette.Colors.Length;
                Native.ApplyPrideAccent(targetHandle, Palette.Colors[colorIndex]);
                accentedHandle = targetHandle;
            }
            else if ((!MasterEnabled || !NativeAccentEnabled) && accentedHandle != IntPtr.Zero)
            {
                Native.ResetPrideAccent(accentedHandle);
                accentedHandle = IntPtr.Zero;
            }

            if (!shouldShow)
            {
                if (Visible) Hide();
                return;
            }

            int padding = 7;
            SetBounds(rect.Left - padding, rect.Top - padding, width + padding * 2, height + padding * 2);
            if (!Visible) Show();
            Native.SetWindowPos(Handle, Native.HWND_TOPMOST, Left, Top, Width, Height, Native.SWP_NOACTIVATE | Native.SWP_SHOWWINDOW);
        }

        private Particle NewParticle(bool burst)
        {
            Color[] colors = Palette.Colors;
            Particle particle = new Particle();
            particle.Color = colors[random.Next(colors.Length)];
            particle.Size = random.Next(5, 13);
            particle.Round = random.Next(0, 4) == 0;
            particle.Angle = random.Next(0, 360);
            particle.Spin = random.Next(-12, 13);
            particle.Burst = burst;

            if (burst)
            {
                particle.X = Math.Max(20, ClientSize.Width / 2 + random.Next(-90, 91));
                particle.Y = Math.Max(20, ClientSize.Height * 3 / 4 + random.Next(-30, 31));
                particle.VelocityX = (float)(random.NextDouble() * 14.0 - 7.0);
                particle.VelocityY = (float)(-4.0 - random.NextDouble() * 10.0);
                particle.Gravity = 0.24f + (float)random.NextDouble() * 0.12f;
            }
            else
            {
                particle.X = random.Next(0, Math.Max(1, ClientSize.Width));
                particle.Y = -20 - random.Next(0, 100);
                particle.VelocityX = (float)(random.NextDouble() * 2.4 - 1.2);
                particle.VelocityY = 2.0f + (float)random.NextDouble() * 3.7f;
                particle.Gravity = 0.012f;
            }
            return particle;
        }

        private void UpdateParticles()
        {
            bool burstActive = DateTime.UtcNow < burstUntil;
            int desired = ConfettiEnabled && MasterEnabled ? 20 + Intensity : 0;
            if (burstActive && MasterEnabled) desired += 140 + Intensity;

            while (particles.Count < desired) particles.Add(NewParticle(burstActive));

            for (int i = particles.Count - 1; i >= 0; i--)
            {
                Particle particle = particles[i];
                particle.X += particle.VelocityX;
                particle.Y += particle.VelocityY;
                particle.VelocityY += particle.Gravity;
                particle.Angle += particle.Spin;

                bool gone = particle.Y > ClientSize.Height + 70 || particle.X < -100 || particle.X > ClientSize.Width + 100;
                bool excess = i >= desired && !particle.Burst;
                if (gone || excess) particles.RemoveAt(i);
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            if (!MasterEnabled || ClientSize.Width < 20 || ClientSize.Height < 20) return;

            Graphics graphics = e.Graphics;
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;

            if (DiscoEnabled) DrawDisco(graphics);
            if (RainbowBorderEnabled) DrawRainbowBorder(graphics);
            if (ConfettiEnabled || DateTime.UtcNow < burstUntil) DrawConfetti(graphics);
            if (BannerEnabled || DateTime.UtcNow < burstUntil) DrawBanner(graphics);
        }

        private ColorBlend MakeBlend(int offset)
        {
            Color[] source = Palette.Colors;
            int count = source.Length + 1;
            Color[] colors = new Color[count];
            float[] positions = new float[count];
            for (int i = 0; i < count; i++)
            {
                colors[i] = source[(i + offset) % source.Length];
                positions[i] = (float)i / (float)(count - 1);
            }
            ColorBlend blend = new ColorBlend(count);
            blend.Colors = colors;
            blend.Positions = positions;
            return blend;
        }

        private void DrawRainbowBorder(Graphics graphics)
        {
            int thickness = 7 + Intensity / 12;
            int offset = (int)(clock.ElapsedMilliseconds / 1200L) % Palette.Colors.Length;
            Rectangle horizontalRect = new Rectangle(0, 0, Math.Max(1, ClientSize.Width), Math.Max(1, thickness));
            Rectangle verticalRect = new Rectangle(0, 0, Math.Max(1, thickness), Math.Max(1, ClientSize.Height));

            using (LinearGradientBrush horizontal = new LinearGradientBrush(horizontalRect, Color.Red, Color.Purple, 0f))
            using (LinearGradientBrush vertical = new LinearGradientBrush(verticalRect, Color.Red, Color.Purple, 90f))
            {
                horizontal.InterpolationColors = MakeBlend(offset);
                vertical.InterpolationColors = MakeBlend(offset + 2);
                graphics.FillRectangle(horizontal, 0, 0, ClientSize.Width, thickness);
                graphics.FillRectangle(horizontal, 0, ClientSize.Height - thickness, ClientSize.Width, thickness);
                graphics.FillRectangle(vertical, 0, 0, thickness, ClientSize.Height);
                graphics.FillRectangle(vertical, ClientSize.Width - thickness, 0, thickness, ClientSize.Height);
            }

            DrawFlag(graphics, thickness + 10, thickness + 10, false);
            DrawFlag(graphics, ClientSize.Width - 84 - thickness, thickness + 10, true);
        }

        private void DrawFlag(Graphics graphics, int x, int y, bool reverse)
        {
            int width = 74;
            int height = 42;
            int stripe = Math.Max(1, height / Palette.Colors.Length);
            for (int i = 0; i < Palette.Colors.Length; i++)
            {
                int index = reverse ? Palette.Colors.Length - 1 - i : i;
                using (SolidBrush brush = new SolidBrush(Palette.Colors[index]))
                    graphics.FillRectangle(brush, x, y + i * stripe, width, stripe + 1);
            }
            using (Pen outline = new Pen(Color.FromArgb(220, Color.White), 2f)) graphics.DrawRectangle(outline, x, y, width, height);
        }

        private void DrawDisco(Graphics graphics)
        {
            int index = (int)(clock.ElapsedMilliseconds / 900L) % Palette.Colors.Length;
            Color color = Palette.Colors[index];
            int width = 16 + Intensity / 7;
            for (int layer = 0; layer < 3; layer++)
            {
                int alpha = 125 - layer * 35;
                using (Pen pen = new Pen(Color.FromArgb(alpha, color), Math.Max(2, width - layer * 5)))
                {
                    int inset = 12 + layer * 7;
                    graphics.DrawRectangle(pen, inset, inset, Math.Max(1, ClientSize.Width - inset * 2 - 1), Math.Max(1, ClientSize.Height - inset * 2 - 1));
                }
            }
        }

        private void DrawConfetti(Graphics graphics)
        {
            foreach (Particle particle in particles)
            {
                GraphicsState state = graphics.Save();
                graphics.TranslateTransform(particle.X, particle.Y);
                graphics.RotateTransform(particle.Angle);
                using (SolidBrush brush = new SolidBrush(particle.Color))
                {
                    if (particle.Round)
                        graphics.FillEllipse(brush, -particle.Size / 2f, -particle.Size / 2f, particle.Size, particle.Size);
                    else
                        graphics.FillRectangle(brush, -particle.Size / 2f, -particle.Size, particle.Size, particle.Size * 2f);
                }
                graphics.Restore(state);
            }
        }

        private static GraphicsPath RoundedRectangle(Rectangle rectangle, int radius)
        {
            GraphicsPath path = new GraphicsPath();
            int diameter = radius * 2;
            path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
            path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            return path;
        }

        private void DrawBanner(Graphics graphics)
        {
            string text = string.IsNullOrWhiteSpace(BannerText) ? "HAPPY PRIDE!  LOVE WINS" : BannerText.Trim();
            bool burst = DateTime.UtcNow < burstUntil;
            float pulse = (float)Math.Sin(clock.ElapsedMilliseconds / 1200.0);
            float fontSize = 20f + (burst ? 4f + pulse * 2f : pulse * 0.8f);
            using (Font font = new Font("Segoe UI", fontSize, FontStyle.Bold, GraphicsUnit.Point))
            {
                SizeF measured = graphics.MeasureString(text, font);
                int width = Math.Min(ClientSize.Width - 40, Math.Max(260, (int)measured.Width + 56));
                int height = Math.Max(64, (int)measured.Height + 25);
                int x = Math.Max(20, (ClientSize.Width - width) / 2);
                int y = 22 + (int)(Math.Sin(clock.ElapsedMilliseconds / 1800.0) * 5.0);
                Rectangle box = new Rectangle(x, y, width, height);

                using (GraphicsPath path = RoundedRectangle(box, 18))
                using (SolidBrush background = new SolidBrush(Color.FromArgb(220, 20, 10, 35)))
                using (Pen outline = new Pen(Color.White, 2f))
                {
                    graphics.FillPath(background, path);
                    graphics.DrawPath(outline, path);
                }

                int stripeWidth = Math.Max(1, width / Palette.Colors.Length);
                for (int i = 0; i < Palette.Colors.Length; i++)
                {
                    using (SolidBrush stripe = new SolidBrush(Palette.Colors[i]))
                        graphics.FillRectangle(stripe, x + i * stripeWidth, y + height - 8, stripeWidth + 1, 8);
                }

                RectangleF textArea = new RectangleF(x + 12, y + 6, width - 24, height - 16);
                using (SolidBrush textBrush = new SolidBrush(Color.White))
                using (StringFormat format = new StringFormat())
                {
                    format.Alignment = StringAlignment.Center;
                    format.LineAlignment = StringAlignment.Center;
                    format.Trimming = StringTrimming.EllipsisCharacter;
                    graphics.DrawString(text, font, textBrush, textArea, format);
                }
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                animationTimer.Stop();
                animationTimer.Dispose();
                if (accentedHandle != IntPtr.Zero) Native.ResetPrideAccent(accentedHandle);
            }
            base.Dispose(disposing);
        }
    }

    internal sealed class RainbowHeader : Panel
    {
        internal PridePalette Palette;
        private readonly System.Windows.Forms.Timer timer;
        private int offset;

        internal RainbowHeader()
        {
            DoubleBuffered = true;
            Palette = ControlForm.Palettes[0];
            timer = new System.Windows.Forms.Timer();
            timer.Interval = 250;
            timer.Tick += delegate { offset++; Invalidate(); };
            timer.Start();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            if (Palette == null || Palette.Colors.Length == 0) return;
            Rectangle rectangle = ClientRectangle;
            if (rectangle.Width <= 0 || rectangle.Height <= 0) return;
            using (LinearGradientBrush brush = new LinearGradientBrush(rectangle, Color.Red, Color.Purple, 0f))
            {
                int count = Palette.Colors.Length + 1;
                ColorBlend blend = new ColorBlend(count);
                Color[] colors = new Color[count];
                float[] positions = new float[count];
                for (int i = 0; i < count; i++)
                {
                    colors[i] = Palette.Colors[(i + offset / 4) % Palette.Colors.Length];
                    positions[i] = (float)i / (float)(count - 1);
                }
                blend.Colors = colors;
                blend.Positions = positions;
                brush.InterpolationColors = blend;
                e.Graphics.FillRectangle(brush, rectangle);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) timer.Dispose();
            base.Dispose(disposing);
        }
    }

    internal sealed class ControlForm : Form
    {
        internal static readonly PridePalette[] Palettes = new PridePalette[]
        {
            new PridePalette("Classic Pride", "#E40303", "#FF8C00", "#FFED00", "#008026", "#004DFF", "#750787"),
            new PridePalette("Progress Pride", "#000000", "#613915", "#74D7EE", "#FFAFC8", "#FFFFFF", "#E40303", "#FF8C00", "#FFED00", "#008026", "#004DFF", "#750787"),
            new PridePalette("Trans Pride", "#5BCEFA", "#F5A9B8", "#FFFFFF", "#F5A9B8", "#5BCEFA"),
            new PridePalette("Bi Pride", "#D60270", "#D60270", "#9B4F96", "#0038A8", "#0038A8"),
            new PridePalette("Pan Pride", "#FF218C", "#FFD800", "#21B1FF"),
            new PridePalette("Lesbian Pride", "#D52D00", "#EF7627", "#FF9A56", "#FFFFFF", "#D162A4", "#B55690", "#A30262")
        };

        private OverlayForm overlay;
        private RainbowHeader header;
        private Label statusLabel;
        private ComboBox targetBox;
        private ComboBox paletteBox;
        private CheckBox borderCheck;
        private CheckBox confettiCheck;
        private CheckBox bannerCheck;
        private CheckBox discoCheck;
        private CheckBox nativeAccentCheck;
        private CheckBox pinCheck;
        private TrackBar intensityBar;
        private Label intensityValue;
        private TextBox bannerText;
        private Button visibilityButton;

        internal ControlForm()
        {
            Text = "Pride Prank Lab";
            ClientSize = new Size(470, 700);
            MinimumSize = new Size(486, 739);
            MaximumSize = new Size(486, 739);
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Color.FromArgb(20, 12, 36);
            ForeColor = Color.White;
            Font = new Font("Segoe UI", 10f, FontStyle.Regular, GraphicsUnit.Point);
            MaximizeBox = false;
            FormBorderStyle = FormBorderStyle.FixedSingle;

            BuildInterface();
            Shown += delegate
            {
                overlay = new OverlayForm(this);
                ApplySettings();
                overlay.Show();
                overlay.RefreshTarget();
                Activate();
            };
            FormClosing += delegate
            {
                if (overlay != null && !overlay.IsDisposed) overlay.Dispose();
            };
        }

        private Label MakeLabel(string text, int x, int y, int width, int height, float size, FontStyle style)
        {
            Label label = new Label();
            label.Text = text;
            label.Location = new Point(x, y);
            label.Size = new Size(width, height);
            label.ForeColor = Color.White;
            label.BackColor = Color.Transparent;
            label.Font = new Font("Segoe UI", size, style, GraphicsUnit.Point);
            return label;
        }

        private CheckBox MakeCheck(string text, int x, int y, bool value)
        {
            CheckBox check = new CheckBox();
            check.Text = text;
            check.Location = new Point(x, y);
            check.Size = new Size(205, 28);
            check.Checked = value;
            check.ForeColor = Color.White;
            check.BackColor = Color.Transparent;
            check.CheckedChanged += delegate { ApplySettings(); };
            return check;
        }

        private Button MakeButton(string text, int x, int y, int width, Color color)
        {
            Button button = new Button();
            button.Text = text;
            button.Location = new Point(x, y);
            button.Size = new Size(width, 42);
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderSize = 1;
            button.FlatAppearance.BorderColor = Color.FromArgb(190, Color.White);
            button.BackColor = color;
            button.ForeColor = Color.White;
            button.Font = new Font("Segoe UI", 10f, FontStyle.Bold, GraphicsUnit.Point);
            button.UseVisualStyleBackColor = false;
            return button;
        }

        private void BuildInterface()
        {
            header = new RainbowHeader();
            header.Location = new Point(0, 0);
            header.Size = new Size(470, 92);
            Controls.Add(header);

            Label title = MakeLabel("PRIDE PRANK LAB", 18, 14, 430, 38, 22f, FontStyle.Bold);
            title.ForeColor = Color.White;
            title.TextAlign = ContentAlignment.MiddleCenter;
            title.BackColor = Color.FromArgb(95, 0, 0, 0);
            header.Controls.Add(title);

            Label subtitle = MakeLabel("Live effects for ChatGPT, Discord, Chrome and Steam - no injection", 18, 55, 430, 25, 9.5f, FontStyle.Bold);
            subtitle.TextAlign = ContentAlignment.MiddleCenter;
            subtitle.BackColor = Color.FromArgb(110, 0, 0, 0);
            header.Controls.Add(subtitle);

            statusLabel = MakeLabel("Looking for a supported app...", 18, 103, 434, 32, 9.5f, FontStyle.Bold);
            statusLabel.BackColor = Color.FromArgb(45, 255, 255, 255);
            statusLabel.TextAlign = ContentAlignment.MiddleCenter;
            Controls.Add(statusLabel);

            Controls.Add(MakeLabel("Target app", 22, 147, 140, 24, 9.5f, FontStyle.Bold));
            targetBox = new ComboBox();
            targetBox.DropDownStyle = ComboBoxStyle.DropDownList;
            targetBox.Location = new Point(164, 144);
            targetBox.Size = new Size(276, 30);
            targetBox.BackColor = Color.FromArgb(42, 26, 64);
            targetBox.ForeColor = Color.White;
            targetBox.Items.Add("Auto (active supported app)");
            targetBox.Items.Add("ChatGPT / Codex");
            targetBox.Items.Add("Discord");
            targetBox.Items.Add("Google Chrome");
            targetBox.Items.Add("Steam");
            targetBox.SelectedIndex = 0;
            targetBox.SelectedIndexChanged += delegate { ApplySettings(); };
            Controls.Add(targetBox);

            Controls.Add(MakeLabel("Pride palette", 22, 185, 140, 24, 9.5f, FontStyle.Bold));
            paletteBox = new ComboBox();
            paletteBox.DropDownStyle = ComboBoxStyle.DropDownList;
            paletteBox.Location = new Point(164, 182);
            paletteBox.Size = new Size(276, 30);
            paletteBox.BackColor = Color.FromArgb(42, 26, 64);
            paletteBox.ForeColor = Color.White;
            foreach (PridePalette palette in Palettes) paletteBox.Items.Add(palette);
            paletteBox.SelectedIndex = 0;
            paletteBox.SelectedIndexChanged += delegate
            {
                header.Palette = (PridePalette)paletteBox.SelectedItem;
                header.Invalidate();
                ApplySettings();
            };
            Controls.Add(paletteBox);

            borderCheck = MakeCheck("Animated rainbow border", 22, 227, true);
            confettiCheck = MakeCheck("Continuous confetti", 240, 227, false);
            bannerCheck = MakeCheck("Pride celebration banner", 22, 260, false);
            discoCheck = MakeCheck("Disco glow", 240, 260, false);
            nativeAccentCheck = MakeCheck("Cycle native window accent", 22, 293, true);
            pinCheck = MakeCheck("Show while app is behind", 240, 293, false);
            Controls.Add(borderCheck);
            Controls.Add(confettiCheck);
            Controls.Add(bannerCheck);
            Controls.Add(discoCheck);
            Controls.Add(nativeAccentCheck);
            Controls.Add(pinCheck);

            Controls.Add(MakeLabel("Chaos intensity", 22, 334, 180, 24, 9.5f, FontStyle.Bold));
            intensityValue = MakeLabel("35%", 376, 334, 64, 24, 9.5f, FontStyle.Bold);
            intensityValue.TextAlign = ContentAlignment.MiddleRight;
            Controls.Add(intensityValue);
            intensityBar = new TrackBar();
            intensityBar.Location = new Point(18, 358);
            intensityBar.Size = new Size(426, 45);
            intensityBar.Minimum = 10;
            intensityBar.Maximum = 100;
            intensityBar.TickFrequency = 10;
            intensityBar.Value = 35;
            intensityBar.BackColor = BackColor;
            intensityBar.ValueChanged += delegate
            {
                intensityValue.Text = intensityBar.Value.ToString() + "%";
                ApplySettings();
            };
            Controls.Add(intensityBar);

            Controls.Add(MakeLabel("Banner message", 22, 412, 180, 24, 9.5f, FontStyle.Bold));
            bannerText = new TextBox();
            bannerText.Location = new Point(22, 439);
            bannerText.Size = new Size(418, 30);
            bannerText.Text = "HAPPY PRIDE!  LOVE WINS";
            bannerText.BackColor = Color.FromArgb(42, 26, 64);
            bannerText.ForeColor = Color.White;
            bannerText.BorderStyle = BorderStyle.FixedSingle;
            bannerText.TextChanged += delegate { ApplySettings(); };
            Controls.Add(bannerText);

            Button celebrate = MakeButton("CELEBRATE!", 22, 487, 202, Color.FromArgb(204, 0, 102));
            celebrate.Click += delegate
            {
                if (overlay != null) overlay.TriggerBurst(6);
                visibilityButton.Text = "Hide effects";
            };
            Controls.Add(celebrate);

            Button maximum = MakeButton("MAXIMUM PRIDE", 238, 487, 202, Color.FromArgb(103, 45, 180));
            maximum.Click += delegate
            {
                borderCheck.Checked = true;
                confettiCheck.Checked = true;
                bannerCheck.Checked = true;
                discoCheck.Checked = true;
                nativeAccentCheck.Checked = true;
                intensityBar.Value = 100;
                paletteBox.SelectedIndex = 1;
                bannerText.Text = "HAPPY PRIDE!  LOVE WINS";
                if (overlay != null) overlay.TriggerBurst(10);
                visibilityButton.Text = "Hide effects";
            };
            Controls.Add(maximum);

            visibilityButton = MakeButton("Hide effects", 22, 543, 202, Color.FromArgb(25, 125, 105));
            visibilityButton.Click += delegate
            {
                if (overlay == null) return;
                overlay.MasterEnabled = !overlay.MasterEnabled;
                visibilityButton.Text = overlay.MasterEnabled ? "Hide effects" : "Show effects";
                overlay.RefreshTarget();
            };
            Controls.Add(visibilityButton);

            Button retarget = MakeButton("Retarget app", 238, 543, 202, Color.FromArgb(25, 92, 156));
            retarget.Click += delegate { if (overlay != null) overlay.RefreshTarget(); };
            Controls.Add(retarget);

            Button quit = MakeButton("QUIT PRIDE LAB", 22, 599, 418, Color.FromArgb(118, 27, 38));
            quit.Click += delegate { Close(); };
            Controls.Add(quit);

            Label footer = MakeLabel("Effects stop instantly when hidden or quit. App installations and project files stay untouched.", 24, 651, 414, 38, 8.5f, FontStyle.Regular);
            footer.ForeColor = Color.FromArgb(215, 205, 230);
            footer.TextAlign = ContentAlignment.MiddleCenter;
            Controls.Add(footer);
        }

        private void ApplySettings()
        {
            if (overlay == null) return;
            string selectedTarget = targetBox.SelectedItem as string ?? "Auto (active supported app)";
            bool targetChanged = overlay.TargetApp != selectedTarget;
            overlay.TargetApp = selectedTarget;
            overlay.Palette = paletteBox.SelectedItem as PridePalette ?? Palettes[0];
            overlay.RainbowBorderEnabled = borderCheck.Checked;
            overlay.ConfettiEnabled = confettiCheck.Checked;
            overlay.BannerEnabled = bannerCheck.Checked;
            overlay.DiscoEnabled = discoCheck.Checked;
            overlay.NativeAccentEnabled = nativeAccentCheck.Checked;
            overlay.PinWhenInactive = pinCheck.Checked;
            overlay.Intensity = intensityBar.Value;
            overlay.BannerText = bannerText.Text;
            overlay.Invalidate();
            if (targetChanged) overlay.RefreshTarget();
        }

        internal void SetTargetStatus(bool attached, string text)
        {
            if (IsDisposed) return;
            if (InvokeRequired)
            {
                BeginInvoke(new Action<bool, string>(SetTargetStatus), attached, text);
                return;
            }
            statusLabel.Text = text;
            statusLabel.ForeColor = attached ? Color.FromArgb(144, 255, 194) : Color.FromArgb(255, 208, 120);
        }
    }

    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            bool created;
            using (Mutex mutex = new Mutex(true, "PridePrankLab-OpenAI-Codex-Overlay", out created))
            {
                if (!created)
                {
                    MessageBox.Show("Pride Prank Lab is already running.", "Pride Prank Lab", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }

                try { Native.SetProcessDPIAware(); } catch { }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                try
                {
                    Application.Run(new ControlForm());
                }
                catch (Exception error)
                {
                    MessageBox.Show("Pride Prank Lab stopped: " + error.Message, "Pride Prank Lab", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }
    }
}
