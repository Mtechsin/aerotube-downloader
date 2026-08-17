const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const sizes = [256, 48, 32, 16];
const base = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'res');

// Load foreground (white icon with alpha) and background (red square)
const fg = PNG.sync.read(fs.readFileSync(path.join(base, 'mipmap-xxxhdpi/ic_launcher_foreground.png')));
const bg = PNG.sync.read(fs.readFileSync(path.join(base, 'mipmap-xxxhdpi/ic_launcher_background.png')));

// Composite foreground over background at given size
function composite(size) {
  const out = new PNG({ width: size, height: size });
  // Scale bg to size
  const bgScaled = scale(bg, size, size);
  const fgScaled = scale(fg, size, size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 4;
      const fr = fgScaled.data[i], fgG = fgScaled.data[i+1], fb = fgScaled.data[i+2], fa = fgScaled.data[i+3] / 255;
      const br = bgScaled.data[i], bgG = bgScaled.data[i+1], bb = bgScaled.data[i+2];
      out.data[i]   = Math.round(fr * fa + br * (1 - fa));
      out.data[i+1] = Math.round(fgG * fa + bgG * (1 - fa));
      out.data[i+2] = Math.round(fb * fa + bb * (1 - fa));
      out.data[i+3] = 255;
    }
  }
  return out;
}

// Simple nearest-neighbor scale
function scale(png, w, h) {
  if (png.width === w && png.height === h) return png;
  const out = new PNG({ width: w, height: h });
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const sx = Math.floor(x * png.width / w);
      const sy = Math.floor(y * png.height / h);
      const si = (sy * png.width + sx) * 4;
      const di = (y * w + x) * 4;
      out.data[di] = png.data[si];
      out.data[di+1] = png.data[si+1];
      out.data[di+2] = png.data[si+2];
      out.data[di+3] = png.data[si+3];
    }
  }
  return out;
}

// Generate combined PNG at 256x256 for use as logo.png
const combined256 = composite(256);
fs.writeFileSync(path.join(__dirname, '..', 'assets', 'images', 'logo.png'), PNG.sync.write(combined256));
console.log('Wrote logo.png (256x256 combined)');

// Generate .ico file with multiple sizes
// ICO format: header + directory entries + image data (PNG-encoded is fine for 256x256, BMP for smaller)
const icons = sizes.map(s => ({ size: s, png: PNG.sync.write(composite(s)) }));

// ICO header: 6 bytes
const header = Buffer.alloc(6);
header.writeUInt16LE(0, 0); // reserved
header.writeUInt16LE(1, 2); // type: 1 = icon
header.writeUInt16LE(icons.length, 4);

// Each directory entry: 16 bytes
let offset = 6 + icons.length * 16;
const entries = icons.map(ic => {
  const entry = Buffer.alloc(16);
  entry.writeUInt8(ic.size === 256 ? 0 : ic.size, 0); // width (0 = 256)
  entry.writeUInt8(ic.size === 256 ? 0 : ic.size, 1); // height
  entry.writeUInt8(0, 2); // color palette
  entry.writeUInt8(0, 3); // reserved
  entry.writeUInt16LE(1, 4); // color planes
  entry.writeUInt16LE(32, 6); // bits per pixel
  entry.writeUInt32LE(ic.png.length, 8); // size of image data
  entry.writeUInt32LE(offset, 12); // offset
  offset += ic.png.length;
  return entry;
});

const ico = Buffer.concat([header, ...entries, ...icons.map(i => i.png)]);
fs.writeFileSync(path.join(__dirname, '..', 'windows', 'runner', 'resources', 'app_icon.ico'), ico);
console.log('Wrote app_icon.ico with sizes:', sizes);
