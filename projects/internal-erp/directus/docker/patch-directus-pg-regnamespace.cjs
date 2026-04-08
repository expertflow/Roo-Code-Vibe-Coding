/**
 * Directus @directus/schema (Postgres) binds schema names as $n::regnamespace.
 * PostgreSQL folds unquoted identifier input to lowercase, so mixed-case schemas
 * (e.g. "BS4Prod09Feb2026") fail with 3F000 unless the bind value is a quoted identifier
 * string: '"BS4Prod09Feb2026"' (see knex-schema-inspector discussion / regnamespace rules).
 *
 * Run at image build time only.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const roots = ['/directus/node_modules'];

function walk(dir, out, depth = 0) {
	if (depth > 25) return;
	let ents;
	try {
		ents = fs.readdirSync(dir, { withFileTypes: true });
	} catch {
		return;
	}
	for (const e of ents) {
		const p = path.join(dir, e.name);
		if (e.isDirectory()) {
			walk(p, out, depth + 1);
			continue;
		}
		if (e.name !== 'index.js') continue;
		const norm = dir.split(path.sep).join('/');
		if (norm.endsWith('@directus/schema/dist')) out.push(p);
	}
}

const needle = 'this.knex.raw("?", [schemaName])}::regnamespace';
const plug =
	'this.knex.raw("?", [\'"\' + String(schemaName).replace(/"/g, \'""\') + \'"\'])}::regnamespace';

const files = [];
for (const r of roots) walk(r, files);

if (files.length === 0) {
	console.error('patch-directus-pg-regnamespace: @directus/schema/dist/index.js not found');
	process.exit(1);
}

for (const f of files) {
	let s = fs.readFileSync(f, 'utf8');
	const count = s.split(needle).length - 1;
	if (count === 0) {
		console.error(`patch-directus-pg-regnamespace: pattern not found in ${f}`);
		process.exit(1);
	}
	s = s.split(needle).join(plug);
	fs.writeFileSync(f, s);
	console.log(`patched ${f} (${count} replacements)`);
}
