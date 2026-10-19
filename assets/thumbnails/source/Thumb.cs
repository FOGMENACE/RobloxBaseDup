using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class Thumb
{
    struct V
    {
        public double X, Y, Z;
        public V(double x, double y, double z) { X = x; Y = y; Z = z; }
        public static V operator +(V a, V b) { return new V(a.X + b.X, a.Y + b.Y, a.Z + b.Z); }
        public static V operator -(V a, V b) { return new V(a.X - b.X, a.Y - b.Y, a.Z - b.Z); }
        public static V operator *(V a, double s) { return new V(a.X * s, a.Y * s, a.Z * s); }
        public static double Dot(V a, V b) { return a.X * b.X + a.Y * b.Y + a.Z * b.Z; }
        public static V Cross(V a, V b) { return new V(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X); }
        public V Norm() { double l = Math.Sqrt(X * X + Y * Y + Z * Z); return l < 1e-9 ? this : new V(X / l, Y / l, Z / l); }
    }

    class Face
    {
        public V[] P;
        public Color C;
        public bool Outline = true;
        public double Bias = 0;
        public string Text;
        public double TextSize = 0.4;
        public bool Flat = false; // no lighting
    }

    static List<Face> faces = new List<Face>();
    static V E, Fw, Rt, Up;
    static double Fpx;
    const int W = 1920, H = 1080;
    static V L = new V(-0.45, 0.85, -0.55).Norm();

    // ---------- math ----------
    static V Rot(V p, V eul)
    {
        double rx = eul.X * Math.PI / 180, ry = eul.Y * Math.PI / 180, rz = eul.Z * Math.PI / 180;
        double y = p.Y * Math.Cos(rx) - p.Z * Math.Sin(rx);
        double z = p.Y * Math.Sin(rx) + p.Z * Math.Cos(rx);
        p = new V(p.X, y, z);
        double x = p.X * Math.Cos(ry) + p.Z * Math.Sin(ry);
        z = -p.X * Math.Sin(ry) + p.Z * Math.Cos(ry);
        p = new V(x, p.Y, z);
        x = p.X * Math.Cos(rz) - p.Y * Math.Sin(rz);
        y = p.X * Math.Sin(rz) + p.Y * Math.Cos(rz);
        return new V(x, y, p.Z);
    }

    static bool Project(V p, out PointF s, out double z)
    {
        V d = p - E;
        double x = V.Dot(d, Rt), y = V.Dot(d, Up);
        z = V.Dot(d, Fw);
        s = new PointF(0, 0);
        if (z < 0.25) return false;
        s = new PointF((float)(W / 2.0 + x / z * Fpx), (float)(H / 2.0 - y / z * Fpx));
        return true;
    }

    static Color Scale(Color c, double k)
    {
        return Color.FromArgb(c.A, (int)Math.Max(0, Math.Min(255, c.R * k)), (int)Math.Max(0, Math.Min(255, c.G * k)), (int)Math.Max(0, Math.Min(255, c.B * k)));
    }

    static Color Hsv(double h, double s, double v)
    {
        h = (h % 1 + 1) % 1 * 6;
        int i = (int)Math.Floor(h);
        double f = h - i, p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f));
        double r, g, b;
        switch (i) { case 0: r = v; g = t; b = p; break; case 1: r = q; g = v; b = p; break; case 2: r = p; g = v; b = t; break; case 3: r = p; g = q; b = v; break; case 4: r = t; g = p; b = v; break; default: r = v; g = p; b = q; break; }
        return Color.FromArgb((int)(r * 255), (int)(g * 255), (int)(b * 255));
    }

    // ---------- geometry builders ----------
    static void AddQuad(V a, V b, V c, V d, Color col, V solidCenter, string text = null, double textSize = 0.4, bool outline = true, double bias = 0)
    {
        V n = V.Cross(b - a, c - a).Norm();
        V fc = (a + b + c + d) * 0.25;
        if (V.Dot(n, fc - solidCenter) < 0) { V t = b; b = d; d = t; n = n * -1; }
        faces.Add(new Face { P = new V[] { a, b, c, d }, C = col, Text = text, TextSize = textSize, Outline = outline, Bias = bias });
    }

    // part with optional root transform (rootPivot, rootEuler) and limb transform (limbPivotLocal, limbEuler)
    static void AddPart(V rootPivot, V rootEul, V limbPivot, V limbEul, V localCenter, V size, Color col, string frontText = null)
    {
        V[] corner = new V[8];
        for (int i = 0; i < 8; i++)
        {
            V o = new V((i & 1) == 0 ? -size.X / 2 : size.X / 2, (i & 2) == 0 ? -size.Y / 2 : size.Y / 2, (i & 4) == 0 ? -size.Z / 2 : size.Z / 2);
            V lp = limbPivot + Rot(localCenter - limbPivot + o, limbEul);
            corner[i] = rootPivot + Rot(lp, rootEul);
        }
        V cen = rootPivot + Rot(limbPivot + Rot(localCenter - limbPivot, limbEul), rootEul);
        int[][] f = new int[][] { new[] { 0, 1, 3, 2 }, new[] { 4, 5, 7, 6 }, new[] { 0, 1, 5, 4 }, new[] { 2, 3, 7, 6 }, new[] { 0, 2, 6, 4 }, new[] { 1, 3, 7, 5 } };
        for (int k = 0; k < 6; k++)
            AddQuad(corner[f[k][0]], corner[f[k][1]], corner[f[k][2]], corner[f[k][3]], col, cen, k == 0 ? frontText : null);
    }

    static void AddBox(V center, V size, V euler, Color col, string frontText = null)
    {
        AddPart(center, euler, new V(0, 0, 0), new V(0, 0, 0), new V(0, 0, 0), size, col, frontText);
    }

    delegate Color ColorAt(double t, double ang);

    static void AddBarrel(V center, V euler, double radius, double length, int seg, int bands, ColorAt colorAt)
    {
        Func<double, double> prof = delegate (double t)
        {
            double r = radius * (1 + 0.07 * Math.Sin(Math.PI * t));
            if (Math.Abs(t - 0.13) < 0.04 || Math.Abs(t - 0.87) < 0.04) r *= 0.94; // rolling hoops
            return r;
        };
        Func<double, double, V> pt = delegate (double t, double a)
        {
            double r = prof(t);
            return center + Rot(new V(r * Math.Cos(a), r * Math.Sin(a), (t - 0.5) * length), euler);
        };
        for (int j = 0; j < bands; j++)
        {
            double t0 = (double)j / bands, t1 = (double)(j + 1) / bands, tm = (t0 + t1) / 2;
            for (int i = 0; i < seg; i++)
            {
                double a0 = 2 * Math.PI * i / seg, a1 = 2 * Math.PI * (i + 1) / seg, am = (a0 + a1) / 2;
                V p0 = pt(t0, a0), p1 = pt(t0, a1), p2 = pt(t1, a1), p3 = pt(t1, a0);
                V axisPt = center + Rot(new V(0, 0, (tm - 0.5) * length), euler);
                AddQuad(p0, p1, p2, p3, colorAt(tm, am), axisPt, null, 0.4, false);
            }
        }
        // end caps
        for (int e = 0; e < 2; e++)
        {
            double t = e;
            double[] rs = { 0.97, 0.80, 0.52 };
            Color[] cs = { Color.FromArgb(150, 156, 170), Color.FromArgb(188, 194, 206), Color.FromArgb(122, 128, 144) };
            for (int k = 0; k < 3; k++)
            {
                V[] ring = new V[seg];
                for (int i = 0; i < seg; i++)
                {
                    double a = 2 * Math.PI * i / seg;
                    double rr = prof(t) * rs[k];
                    ring[i] = center + Rot(new V(rr * Math.Cos(a), rr * Math.Sin(a), (t - 0.5) * length + (e == 0 ? -1 : 1) * 0.02 * (k + 1)), euler);
                }
                faces.Add(new Face { P = ring, C = cs[k], Outline = k == 0, Bias = -0.01 * (k + 1) });
            }
            // two bungs
            V bungDir = Rot(new V(0, 0, e == 0 ? -1 : 1), euler);
            for (int b = 0; b < 2; b++)
            {
                double ba = b == 0 ? 0.9 : 3.5;
                V c0 = center + Rot(new V(prof(t) * 0.58 * Math.Cos(ba), prof(t) * 0.58 * Math.Sin(ba), (t - 0.5) * length + (e == 0 ? -1 : 1) * 0.08), euler);
                int n = 14; V[] disc = new V[n];
                for (int i = 0; i < n; i++)
                {
                    double a = 2 * Math.PI * i / n;
                    disc[i] = c0 + Rot(new V(0.22 * Math.Cos(a), 0.22 * Math.Sin(a), 0), euler);
                }
                faces.Add(new Face { P = disc, C = Color.FromArgb(96, 102, 118), Outline = true, Bias = -0.05 });
            }
        }
    }

    // ---------- render ----------
    static double FaceDepth(Face f)
    {
        double s = 0; int n = 0;
        foreach (V p in f.P) { s += V.Dot(p - E, Fw); n++; }
        return s / n + f.Bias;
    }

    static void DrawFaces(Graphics g)
    {
        List<Face> list = new List<Face>(faces);
        list.Sort(delegate (Face a, Face b) { return FaceDepth(b).CompareTo(FaceDepth(a)); });
        foreach (Face f in list)
        {
            V n = V.Cross(f.P[1] - f.P[0], f.P[2] - f.P[0]).Norm();
            V fc = new V(0, 0, 0);
            foreach (V p in f.P) fc = fc + p;
            fc = fc * (1.0 / f.P.Length);
            // faces are wound arbitrarily: light with the normal turned toward the camera
            if (V.Dot(n, E - fc) < 0) n = n * -1;
            double b = f.Flat ? 1.0 : 0.60 + 0.42 * Math.Max(0, V.Dot(n, L));
            PointF[] pts = new PointF[f.P.Length];
            bool ok = true;
            for (int i = 0; i < pts.Length; i++)
            {
                double z; PointF s;
                if (!Project(f.P[i], out s, out z)) { ok = false; break; }
                pts[i] = s;
            }
            if (!ok) continue;
            // cull solid faces that look away (boxes pass a solid centre through AddQuad: handled by winding fix)
            Color col = Scale(f.C, b);
            using (SolidBrush br = new SolidBrush(col)) g.FillPolygon(br, pts);
            if (!f.Outline)
                using (Pen seam = new Pen(col, 1.4f) { LineJoin = LineJoin.Round }) g.DrawPolygon(seam, pts);
            if (f.Outline)
                using (Pen pen = new Pen(Color.FromArgb(120, 25, 20, 45), 2.2f) { LineJoin = LineJoin.Round }) g.DrawPolygon(pen, pts);
            if (f.Text != null)
            {
                float minX = float.MaxValue, maxX = float.MinValue, minY = float.MaxValue, maxY = float.MinValue;
                foreach (PointF p in pts) { minX = Math.Min(minX, p.X); maxX = Math.Max(maxX, p.X); minY = Math.Min(minY, p.Y); maxY = Math.Max(maxY, p.Y); }
                float size = (float)((maxY - minY) * f.TextSize);
                OutlinedText(g, f.Text, (minX + maxX) / 2, (minY + maxY) / 2, size, Color.White, Color.FromArgb(24, 20, 44), size / 9f, 0);
            }
        }
    }

    static void OutlinedText(Graphics g, string text, float cx, float cy, float size, Color fill, Color outline, float thickness, float rot, Color? fill2 = null)
    {
        using (GraphicsPath path = new GraphicsPath())
        using (Font font = new Font("Arial Black", size, FontStyle.Bold, GraphicsUnit.Pixel))
        using (StringFormat sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
        {
            path.AddString(text, font.FontFamily, (int)FontStyle.Bold, size, new PointF(0, 0), sf);
            GraphicsState st = g.Save();
            g.TranslateTransform(cx, cy);
            g.RotateTransform(rot);
            // soft shadow
            g.TranslateTransform(0, size * 0.06f);
            using (SolidBrush sh = new SolidBrush(Color.FromArgb(90, 10, 10, 30))) g.FillPath(sh, path);
            g.TranslateTransform(0, -size * 0.06f);
            using (Pen pen = new Pen(outline, thickness * 2) { LineJoin = LineJoin.Round }) g.DrawPath(pen, path);
            RectangleF bounds = path.GetBounds();
            if (fill2.HasValue)
                using (LinearGradientBrush lb = new LinearGradientBrush(new RectangleF(bounds.X, bounds.Y - 1, bounds.Width, bounds.Height + 2), fill, fill2.Value, 90f)) g.FillPath(lb, path);
            else
                using (SolidBrush br = new SolidBrush(fill)) g.FillPath(br, path);
            g.Restore(st);
        }
    }

    // ---------- scene ----------
    public static void Render(string outPath, bool title)
    {
        faces.Clear();
        E = new V(-2.6, 5.0, -9.0);
        V target = new V(2.2, 4.6, 40);
        Fw = (target - E).Norm();
        Rt = V.Cross(new V(0, 1, 0), Fw).Norm();
        Up = V.Cross(Fw, Rt).Norm();
        double fov = 60 * Math.PI / 180;
        Fpx = (H / 2.0) / Math.Tan(fov / 2);

        // lane tiles
        for (int row = -2; row < 40; row++)
            for (int col = 0; col < 8; col++)
            {
                double z0 = row * 4, z1 = z0 + 4, x0 = -12 + col * 3, x1 = x0 + 3;
                double hue = row * 0.032 + col * 0.045;
                Color c = Hsv(hue, 0.72, 1.0);
                V a = new V(x0, 0, z0), b = new V(x1, 0, z0), cc = new V(x1, 0, z1), d = new V(x0, 0, z1);
                faces.Add(new Face { P = new V[] { a, b, cc, d }, C = c, Outline = false });
            }
        // rails
        foreach (int side in new[] { -1, 1 })
        {
            V c0 = new V(side * 12.9, 0.7, 70);
            AddBox(c0, new V(1.6, 1.4, 160), new V(0, 0, 0), Color.FromArgb(44, 48, 96));
            AddBox(new V(side * 12.1, 1.42, 70), new V(0.25, 0.08, 160), new V(0, 0, 0), Color.FromArgb(245, 246, 255));
        }

        // soft colourful block towers in the distance
        Random rng = new Random(11);
        for (int i = 0; i < 18; i++)
        {
            int side = (i % 2 == 0) ? 1 : -1;
            double x = side * (20 + rng.NextDouble() * 55), z = 25 + rng.NextDouble() * 110, h = 6 + rng.NextDouble() * 26, w = 7 + rng.NextDouble() * 9;
            Color c = Hsv(rng.NextDouble(), 0.42, 0.97);
            AddBox(new V(x, h / 2 - 1, z), new V(w, h, w), new V(0, 0, 0), c);
            if (rng.NextDouble() < 0.7) AddBox(new V(x, h - 1 + h * 0.1, z), new V(w * 0.7, h * 0.2, w * 0.7), new V(0, 0, 0), Hsv(rng.NextDouble(), 0.45, 0.98));
        }

        // end boards (the oil platforms): +999 green, -67 red, on the black stand
        AddBox(new V(0, 8.2, 43.6), new V(29, 14.6, 1.0), new V(0, 0, 0), Color.FromArgb(26, 26, 36));
        AddBox(new V(-7.2, 8.2, 42.2), new V(13.4, 13.6, 0.7), new V(0, 0, 0), Color.FromArgb(48, 214, 78), "+999");
        AddBox(new V(7.2, 8.2, 42.2), new V(13.4, 13.6, 0.7), new V(0, 0, 0), Color.FromArgb(236, 52, 62), "-67");
        foreach (double px in new[] { -12.2, -2.2, 2.2, 12.2 })
            AddBox(new V(px, 15.6, 42.2), new V(0.8, 1.6, 0.8), new V(0, 0, 0), Color.FromArgb(34, 34, 46));

        // ---------- rainbow oil barrel, rolling away toward the boards ----------
        ColorAt barrel = delegate (double t, double ang)
        {
            // rainbow along the barrel with a white OIL label on the camera-facing side
            double deg = (ang * 180 / Math.PI + 360) % 360;
            if (t > 0.26 && t < 0.74 && (deg > 346 || deg < 52)) return Color.FromArgb(246, 246, 250);
            return Hsv(0.92 - t * 0.92, 0.82, 1.0);
        };
        V bc = new V(2.6, 2.7, 9.0);
        V be = new V(0, 68, 0);
        AddBarrel(bc, be, 2.7, 7.4, 44, 30, barrel);
        // label text anchor (flat quad in the label window)
        // (the text itself is drawn after the faces from a projected point, see below)

        // ---------- the Roblox guy (back 3/4 view, lunging forward) ----------
        double s = 1.15;
        V hip = new V(-6.2, 1.75 * s, 4.2);
        Color skin = Color.FromArgb(255, 205, 160), red = Color.FromArgb(222, 46, 52), redD = Color.FromArgb(188, 34, 44), dark = Color.FromArgb(44, 46, 58), hair = Color.FromArgb(124, 70, 34), shoe = Color.FromArgb(244, 244, 250);
        V lean = new V(24, -6, 0);
        // legs (not leaning with the torso)
        AddPart(hip, new V(0, -6, 0), new V(0.55 * s, 0, 0), new V(-40, 0, 0), new V(0.55 * s, -1.0 * s, 0), new V(1.0 * s, 2.0 * s, 1.0 * s), dark);
        AddPart(hip, new V(0, -6, 0), new V(0.55 * s, 0, 0), new V(-40, 0, 0), new V(0.55 * s, -2.1 * s, 0.1 * s), new V(1.08 * s, 0.5 * s, 1.45 * s), shoe);
        AddPart(hip, new V(0, -6, 0), new V(-0.55 * s, 0, 0), new V(34, 0, 0), new V(-0.55 * s, -1.0 * s, 0), new V(1.0 * s, 2.0 * s, 1.0 * s), dark);
        AddPart(hip, new V(0, -6, 0), new V(-0.55 * s, 0, 0), new V(34, 0, 0), new V(-0.55 * s, -2.1 * s, 0.1 * s), new V(1.08 * s, 0.5 * s, 1.45 * s), shoe);
        // torso, hoodie, head
        AddPart(hip, lean, new V(0, 0, 0), new V(0, 0, 0), new V(0, 1.05 * s, 0), new V(2.1 * s, 2.1 * s, 1.1 * s), red);
        AddPart(hip, lean, new V(0, 0, 0), new V(0, 0, 0), new V(0, 0.08 * s, 0), new V(2.2 * s, 0.34 * s, 1.2 * s), redD);
        AddPart(hip, lean, new V(0, 0, 0), new V(0, 0, 0), new V(0, 2.15 * s, -0.55 * s), new V(1.9 * s, 0.9 * s, 0.7 * s), redD);   // hood on his back
        // arms (sleeves + hands)
        AddPart(hip, lean, new V(1.6 * s, 1.95 * s, 0), new V(-76, 0, -6), new V(1.6 * s, 1.95 * s - 0.75 * s, 0), new V(1.05 * s, 1.5 * s, 1.05 * s), red);
        AddPart(hip, lean, new V(1.6 * s, 1.95 * s, 0), new V(-76, 0, -6), new V(1.6 * s, 1.95 * s - 1.8 * s, 0), new V(0.95 * s, 0.65 * s, 0.95 * s), skin);
        AddPart(hip, lean, new V(-1.6 * s, 1.95 * s, 0), new V(46, 0, 8), new V(-1.6 * s, 1.95 * s - 0.75 * s, 0), new V(1.05 * s, 1.5 * s, 1.05 * s), red);
        AddPart(hip, lean, new V(-1.6 * s, 1.95 * s, 0), new V(46, 0, 8), new V(-1.6 * s, 1.95 * s - 1.8 * s, 0), new V(0.95 * s, 0.65 * s, 0.95 * s), skin);
        // head + spiky hair
        V headC = new V(0.05 * s, 3.25 * s, 0.1 * s);
        V headE = new V(0, -22, 0);
        AddPart(hip, lean, headC, headE, headC, new V(1.75 * s, 1.75 * s, 1.75 * s), skin);
        AddPart(hip, lean, headC, headE, headC + new V(0, 0.95 * s, 0), new V(1.95 * s, 0.55 * s, 1.95 * s), hair);
        AddPart(hip, lean, headC, headE, headC + new V(0, 0.05 * s, -0.78 * s), new V(1.95 * s, 1.7 * s, 0.5 * s), hair);
        AddPart(hip, lean, headC, headE, headC + new V(-0.98 * s, 0.1 * s, 0), new V(0.3 * s, 1.5 * s, 1.9 * s), hair);
        AddPart(hip, lean, headC, headE, headC + new V(0.98 * s, 0.1 * s, 0), new V(0.3 * s, 1.5 * s, 1.9 * s), hair);
        double[][] spikes = {
            new double[]{-0.7, 1.35, -0.1, 0.45, 0.95, 0.45, 24},
            new double[]{ 0.0, 1.5, 0.25, 0.5, 1.1, 0.5, -8},
            new double[]{ 0.7, 1.35, 0.1, 0.45, 0.95, 0.45, -26},
            new double[]{-0.3, 1.45, -0.55, 0.5, 1.0, 0.5, 10},
            new double[]{ 0.45, 1.4, -0.5, 0.5, 0.95, 0.5, -14},
            new double[]{ 0.0, 1.3, -0.8, 0.5, 0.9, 0.5, 0},
        };
        foreach (double[] sp in spikes)
            AddPart(hip, lean, headC, headE, headC + new V(sp[0] * s, sp[1] * s, sp[2] * s), new V(sp[3] * s, sp[4] * s, sp[5] * s), Scale(hair, 1.08), null);

        // ---------- draw ----------
        using (Bitmap bmp = new Bitmap(W, H))
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;

            // sky
            using (LinearGradientBrush sky = new LinearGradientBrush(new Rectangle(0, 0, W, H / 2 + 140), Color.FromArgb(34, 124, 232), Color.FromArgb(176, 224, 255), 90f))
                g.FillRectangle(sky, 0, 0, W, H);
            // clouds
            Random cr = new Random(5);
            for (int i = 0; i < 9; i++)
            {
                float cx = (float)(cr.NextDouble() * W), cy = (float)(60 + cr.NextDouble() * 260), cw = (float)(260 + cr.NextDouble() * 360);
                using (SolidBrush cb = new SolidBrush(Color.FromArgb(150, 255, 255, 255)))
                {
                    g.FillEllipse(cb, cx, cy, cw, cw * 0.28f);
                    g.FillEllipse(cb, cx + cw * 0.2f, cy - cw * 0.12f, cw * 0.5f, cw * 0.3f);
                    g.FillEllipse(cb, cx + cw * 0.5f, cy - cw * 0.04f, cw * 0.4f, cw * 0.24f);
                }
            }
            // ground haze below the horizon
            PointF hz; double zz;
            Project(new V(0, 0, 400), out hz, out zz);
            using (LinearGradientBrush gr = new LinearGradientBrush(new RectangleF(0, hz.Y - 2, W, H - hz.Y + 2), Color.FromArgb(190, 226, 255), Color.FromArgb(150, 190, 250), 90f))
                g.FillRectangle(gr, 0, hz.Y, W, H - hz.Y);

            DrawFaces(g);

            // OIL label on the barrel
            {
                V axisPt = bc + Rot(new V(0, 0, 0), be);
                double a = 14 * Math.PI / 180;
                V lp = bc + Rot(new V(2.7 * Math.Cos(a), 2.7 * Math.Sin(a), 0), be);
                PointF p0, p1; double z0, z1;
                Project(lp, out p0, out z0);
                Project(lp + Rot(new V(0, 0, 1), be), out p1, out z1);
                float ang = (float)(Math.Atan2(p1.Y - p0.Y, p1.X - p0.X) * 180 / Math.PI);
                if (ang > 90) ang -= 180; if (ang < -90) ang += 180;
                float size = (float)(Fpx / z0 * 1.3);
                OutlinedText(g, "OIL", p0.X, p0.Y, size, Color.FromArgb(24, 24, 40), Color.FromArgb(246, 246, 250), 1.5f, ang);
            }

            // speed streaks behind the barrel
            PointF sb; double sz;
            Project(bc + new V(-0.4, -0.3, -3.2), out sb, out sz);
            Random sr = new Random(3);
            for (int i = 0; i < 16; i++)
            {
                float dx = (float)(-380 - sr.NextDouble() * 420), dy = (float)(160 + sr.NextDouble() * 240);
                float off = (float)((sr.NextDouble() - 0.5) * 150);
                PointF a = new PointF(sb.X + off * 0.4f, sb.Y + off);
                PointF b = new PointF(a.X + dx, a.Y + dy * 0.55f);
                Color c = Hsv(i / 16.0, 0.65, 1.0);
                using (LinearGradientBrush lb = new LinearGradientBrush(a, b, Color.FromArgb(200, c), Color.FromArgb(0, c)))
                using (Pen pen = new Pen(lb, (float)(3 + sr.NextDouble() * 5)) { StartCap = LineCap.Round })
                    g.DrawLine(pen, a, b);
            }

            // clean +1s: flat white text, solid green outline, no stickers
            float[][] ones = {
                new float[]{ 1760, 150, 120, 8 }, new float[]{ 1480, 80, 92, -6 }, new float[]{ 905, 70, 64, -5 }, new float[]{ 600, 60, 90, 6 },
                new float[]{ 1130, 330, 56, 9 }, new float[]{ 1700, 420, 82, -9 }, new float[]{ 1620, 700, 100, 7 }, new float[]{ 1330, 360, 60, -8 },
                new float[]{ 1120, 900, 120, -6 }, new float[]{ 1760, 880, 140, 8 }, new float[]{ 700, 300, 58, 8 }, new float[]{ 1860, 640, 70, -10 },
                new float[]{ 460, 120, 70, -7 },
            };
            foreach (float[] o in ones)
            {
                if (title && o[1] < 230) continue;
                OutlinedText(g, "+1", o[0], o[1], o[2], Color.White, Color.FromArgb(18, 138, 52), o[2] / 11f, o[3], Color.FromArgb(214, 255, 190));
            }

            if (title)
            {
                OutlinedText(g, "+1 OIL BOWLING", W / 2f, 118, 150, Color.FromArgb(255, 248, 120), Color.FromArgb(30, 16, 80), 15, 0, Color.FromArgb(255, 160, 30));
            }

            bmp.Save(outPath, ImageFormat.Png);
        }
    }
}
