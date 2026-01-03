using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Drawing.Drawing2D;

namespace MarkdownViewerHost
{
    public static class IconHelper
    {
        public static Bitmap GetIconBySize(Stream iconStream, int targetSize, bool scaleToTarget = false)
        {
            if (iconStream == null) throw new ArgumentNullException(nameof(iconStream));
            iconStream.Position = 0;

            var entries = new List<(int w, int h, int imgSize, int imgOffset)>();
            using (BinaryReader reader = new BinaryReader(iconStream, System.Text.Encoding.Default, true))
            {
                iconStream.Seek(4, SeekOrigin.Begin);
                short count = reader.ReadInt16();
                for (int i = 0; i < count; i++)
                {
                    byte w = reader.ReadByte();
                    byte h = reader.ReadByte();
                    int actualW = (w == 0) ? 256 : w;
                    int actualH = (h == 0) ? 256 : h;
                    iconStream.Seek(6, SeekOrigin.Current);
                    int imgSize = reader.ReadInt32();
                    int imgOffset = reader.ReadInt32();
                    entries.Add((actualW, actualH, imgSize, imgOffset));
                }

        if (entries.Count == 0)
            throw new InvalidOperationException("ICO file contains no valid images");
                var bestEntry = entries
                    .Where(e => e.w >= targetSize && e.h >= targetSize)
                    .OrderBy(e => e.w * e.h)
                    .FirstOrDefault();

                // If no entry is large enough, just grab the largest available
                if (bestEntry.w == 0) bestEntry = entries.OrderByDescending(e => e.w * e.h).First();

                iconStream.Seek(bestEntry.imgOffset, SeekOrigin.Begin);
                byte[] rawData = reader.ReadBytes(bestEntry.imgSize);

                if (IsPng(rawData))
                {
                    using var ms = new MemoryStream(rawData);
                    using var tmp = new Bitmap(ms);
                    // Clone detaches the bitmap from the stream so we can close the stream safely
                    var bitmap = tmp.Clone(new Rectangle(0, 0, tmp.Width, tmp.Height), tmp.PixelFormat);
                    return scaleToTarget ? ScaleBitmap(bitmap, targetSize) : bitmap;
                }

                var icoBitmap = CreateBitmapFromIcoBmp(rawData);
                return scaleToTarget ? ScaleBitmap(icoBitmap, targetSize) : icoBitmap;
            }
        }

        private static Bitmap CreateBitmapFromIcoBmp(byte[] icoBmpData)
        {
            // 1. Fix Height (biHeight / 2) because ICO BMPs have double height in header
            int biHeight = BitConverter.ToInt32(icoBmpData, 8);
            int actualHeight = biHeight / 2;
            BitConverter.GetBytes(actualHeight).CopyTo(icoBmpData, 8);

            int infoHeaderSize = BitConverter.ToInt32(icoBmpData, 0);
            int width = BitConverter.ToInt32(icoBmpData, 4);

            // 2. Locate Pixel Data
            int pixelDataOffset = infoHeaderSize;
            int totalPixelBytes = width * actualHeight * 4;

            // 3. Create ARGB Canvas
            Bitmap final = new Bitmap(width, actualHeight, PixelFormat.Format32bppArgb);
            var rect = new Rectangle(0, 0, width, actualHeight);
            var bmpData = final.LockBits(rect, ImageLockMode.WriteOnly, final.PixelFormat);

            // 4. Copy raw ARGB bytes
            int bytesToCopy = Math.Min(totalPixelBytes, icoBmpData.Length - pixelDataOffset);
            Marshal.Copy(icoBmpData, pixelDataOffset, bmpData.Scan0, bytesToCopy);

            final.UnlockBits(bmpData);

            // 5. Flip vertically (ICO BMPs are bottom-up)
            final.RotateFlip(RotateFlipType.RotateNoneFlipY);

            return final;
        }

        private static bool IsPng(byte[] data)
        {
            if (data.Length < 8) return false;
            return data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 &&
                   data[4] == 0x0D && data[5] == 0x0A && data[6] == 0x1A && data[7] == 0x0A;
        }

        private static Bitmap ScaleBitmap(Bitmap source, int targetSize)
        {
            var scaled = new Bitmap(targetSize, targetSize);
            using (var g = Graphics.FromImage(scaled))
            {
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.DrawImage(source, 0, 0, targetSize, targetSize);
            }
            return scaled;
        }
    }
}