const PDF = require('pdfkit');
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==','base64');
const doc = new PDF({ size: 'A4', margin: 28 });
let done = false;
doc.on('data', () => {});
doc.on('end', () => { done = true; console.log('END event fired'); process.exit(0); });
doc.on('error', (e) => { console.log('ERROR event', e.message); process.exit(1); });
doc.text('hello');
try { doc.image(png, 100, 100, { fit: [16,16] }); console.log('image added'); } catch(e){ console.log('image throw', e.message); }
doc.text('after image');
doc.end();
setTimeout(() => { console.log('TIMEOUT done=' + done); process.exit(2); }, 5000);
