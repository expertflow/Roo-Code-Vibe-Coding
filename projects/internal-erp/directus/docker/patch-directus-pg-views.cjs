/**
 * Patches @directus/schema (Postgres dialect) to include VIEW types
 * alongside BASE TABLE in schema introspection queries.
 *
 * By default, Directus only introspects tables with table_type = 'BASE TABLE'.
 * This patch adds 'VIEW' so that PostgreSQL views are discoverable as collections.
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

const files = [];
for (const r of roots) walk(r, files);

if (files.length === 0) {
	console.error('patch-directus-pg-views: @directus/schema/dist/index.js not found');
	process.exit(1);
}

// Patterns to replace - Directus uses 'BASE TABLE' in multiple places in its
// table introspection queries to filter types. We need to include 'VIEW' as well.
const replacements = [
	// tableInfo() WHERE clause: table_type = 'BASE TABLE'
	{
		needle: "'BASE TABLE' AND",
		plug: "'BASE TABLE' AND",  // keep as-is, only change IN-list patterns
		skip: true
	},
	// Pattern in postgres.ts: .where('table_type', 'BASE TABLE')
	{
		needle: '"table_type","BASE TABLE"',
		plug: '"table_type","BASE TABLE"',
		skip: true
	},
	// Main IN-list pattern used in knex-schema-inspector postgres dialect
	// .whereIn('table_type', ['BASE TABLE'])
	{
		needle: "['BASE TABLE']",
		plug: "['BASE TABLE','VIEW']"
	},
	// .whereIn("table_type", ["BASE TABLE"])
	{
		needle: '["BASE TABLE"]',
		plug: '["BASE TABLE","VIEW"]'
	},
	// single-quoted IN list (minified)
	{
		needle: "['BASE TABLE']",
		plug: "['BASE TABLE','VIEW']"
	}
];

let totalPatches = 0;

for (const f of files) {
	let s = fs.readFileSync(f, 'utf8');
	let patched = false;

	for (const r of replacements) {
		if (r.skip) continue;
		const count = s.split(r.needle).length - 1;
		if (count > 0) {
			s = s.split(r.needle).join(r.plug);
			console.log(`patched ${f}: replaced "${r.needle}" -> "${r.plug}" (${count}x)`);
			totalPatches += count;
			patched = true;
		}
	}

	// Also handle: .where("TABLE_TYPE","BASE TABLE") or .where('TABLE_TYPE','BASE TABLE')
	// and: table_type in ('BASE TABLE') or table_type IN ('BASE TABLE')
	const patterns = [
		[/\.where\(["']table_type["']\s*,\s*["']BASE TABLE["']\)/g,
		 '.whereIn("table_type",["BASE TABLE","VIEW"])'],
		[/table_type\s+in\s*\(\s*["']BASE TABLE["']\s*\)/gi,
		 "table_type IN ('BASE TABLE','VIEW')"],
		[/table_type\s*=\s*["']BASE TABLE["']/gi,
		 "table_type IN ('BASE TABLE','VIEW')"]
	];

	for (const [re, repl] of patterns) {
		const before = s;
		s = s.replace(re, repl);
		if (s !== before && !patched) {
			console.log(`patched ${f}: regex replacement "${re}"`);
			totalPatches++;
			patched = true;
		}
	}

	if (patched) {
		fs.writeFileSync(f, s);
	} else {
		console.warn(`patch-directus-pg-views: no patterns matched in ${f}, file may already be patched or pattern changed`);
	}
}

if (totalPatches === 0) {
	console.warn('patch-directus-pg-views: no patches applied - please verify the schema inspector source manually');
	// Don't exit(1) — allow build to proceed since the file might use a different pattern
}

console.log(`patch-directus-pg-views: done (${totalPatches} replacements total)`);
