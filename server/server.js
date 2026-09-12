const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = Number(process.env.PORT) || 8080;
const publicDir = path.join(__dirname, 'public');
const downloadsDir = path.join(__dirname, 'downloads');

function sendDownload(res, filePath, contentType, filename) {
  if (!fs.existsSync(filePath)) {
    res.status(404).type('text/plain').send('Archivo no disponible en este despliegue.');
    return;
  }
  res.setHeader('Content-Type', contentType);
  res.setHeader('Content-Disposition', 'attachment; filename="' + filename + '"');
  res.setHeader('Cache-Control', 'public, max-age=3600');
  res.sendFile(filePath);
}

app.get('/downloads/olivo.apk', (req, res) => {
  sendDownload(
    res,
    path.join(downloadsDir, 'olivo.apk'),
    'application/vnd.android.package-archive',
    'olivo.apk',
  );
});

app.get('/downloads/olivo-android.zip', (req, res) => {
  sendDownload(
    res,
    path.join(downloadsDir, 'olivo-android.zip'),
    'application/zip',
    'olivo-android.zip',
  );
});

app.get('/downloads/olivo-ios.zip', (req, res) => {
  sendDownload(
    res,
    path.join(downloadsDir, 'olivo-ios.zip'),
    'application/zip',
    'olivo-ios.zip',
  );
});

app.use(express.static(publicDir, { index: 'index.html' }));

app.get('*', (req, res) => {
  res.sendFile(path.join(publicDir, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('olivo-flutter listening on 0.0.0.0:' + PORT);
});
