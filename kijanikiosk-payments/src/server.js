'use strict';

const http = require('node:http');
const pkg = require('../package.json');
const payments = require('./index.js');

const port = Number(process.env.PORT || 3001);
const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', version: `v${pkg.version}` }));
    return;
  }
  if (req.method === 'GET' && req.url === '/quote') {
    const amount = Number(new URL(req.url, 'http://localhost').searchParams.get('amount'));
    try {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify(payments.quote(amount)));
    } catch (error) {
      res.writeHead(400, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: error.message }));
    }
    return;
  }
  res.writeHead(404, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ error: 'not found' }));
});

server.listen(port, '0.0.0.0', () => console.log(`kk-payments listening on ${port}`));
