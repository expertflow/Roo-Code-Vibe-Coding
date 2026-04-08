/**
 * Story 3-1b/c — Authenticated POST runs repo Python importer, then creates BankStatement rows
 * (items.create → dedup hook). JSON body: { account, csv, dryRun? }.
 *
 * Env:
 *   BANK_IMPORT_PYTHON — default python3
 *   BANK_IMPORT_DIR — default /directus/bank-import (repo package root with cli.py)
 *   BANK_IMPORT_MAX_BYTES — max CSV UTF-8 size (default 15MB)
 */

import { execFile } from 'child_process';
import { promisify } from 'util';
import { writeFile, mkdtemp, rm } from 'fs/promises';
import { join } from 'path';
import { tmpdir } from 'os';

const execFileAsync = promisify(execFile);

const PYTHON = process.env.BANK_IMPORT_PYTHON || 'python3';
const BANK_IMPORT_DIR = process.env.BANK_IMPORT_DIR || '/directus/bank-import';
const MAX_CSV = Number(process.env.BANK_IMPORT_MAX_BYTES || String(15 * 1024 * 1024));

export default {
  id: 'bank-statement-import',
  handler: (router, { services, database, getSchema, logger }) => {
    router.post('/run', async (req, res, next) => {
      try {
        if (!req.accountability?.user) {
          return res.status(403).json({ error: 'Forbidden' });
        }

        const body = req.body;
        const accountRaw = body?.account;
        const account =
          typeof accountRaw === 'number' ? accountRaw : parseInt(String(accountRaw ?? ''), 10);
        if (Number.isNaN(account)) {
          return res.status(400).json({ error: 'account (integer) is required' });
        }

        const fileId = body?.fileId;
        let csvText = body?.csv;

        if (fileId && !csvText) {
          try {
            const schema = await getSchema();
            const filesService = new services.FilesService({
              schema,
              knex: database,
              accountability: req.accountability,
            });
            const stream = await filesService.readStream(fileId);
            const chunks = [];
            for await (const chunk of stream.stream) {
              chunks.push(chunk);
            }
            csvText = Buffer.concat(chunks).toString('utf8');
          } catch (e) {
            logger?.error?.(e);
            return res.status(400).json({ error: `Failed to read file ${fileId}: ${e.message}` });
          }
        }

        if (typeof csvText !== 'string' || !csvText.trim()) {
          return res.status(400).json({ error: 'csv (text) or fileId is required' });
        }
        if (Buffer.byteLength(csvText, 'utf8') > MAX_CSV) {
          return res.status(413).json({ error: `csv exceeds max size (${MAX_CSV} bytes)` });
        }

        const dryRun = Boolean(body?.dryRun);

        const dir = await mkdtemp(join(tmpdir(), 'bank-import-'));
        const csvPath = join(dir, 'upload.csv');
        await writeFile(csvPath, csvText, 'utf8');

        const cliPath = join(BANK_IMPORT_DIR, 'cli.py');
        let stdout;
        try {
          const r = await execFileAsync(
            PYTHON,
            [cliPath, '--input', csvPath, '--account', String(account), '--format', 'json', '--output', '-'],
            {
              cwd: BANK_IMPORT_DIR,
              maxBuffer: 32 * 1024 * 1024,
              windowsHide: true,
            },
          );
          stdout = r.stdout;
        } catch (e) {
          logger?.error?.(e);
          const stderr = e.stderr?.toString?.() || '';
          const msg = stderr.trim() || e.message || 'Python importer failed';
          await rm(dir, { recursive: true, force: true });
          return res.status(400).json({ error: msg });
        }
        await rm(dir, { recursive: true, force: true });

        let rows;
        try {
          rows = JSON.parse(stdout);
        } catch (e) {
          logger?.error?.(e);
          return res.status(500).json({ error: 'Invalid JSON from bank-import CLI' });
        }
        if (!Array.isArray(rows)) {
          return res.status(500).json({ error: 'Importer did not return a JSON array' });
        }

        if (dryRun) {
          return res.json({ dryRun: true, count: rows.length, rows });
        }

        const schema = await getSchema();
        const { ItemsService } = services;
        const items = new ItemsService('BankStatement', {
          knex: database,
          schema,
          accountability: { admin: true, user: req.accountability.user },
        });

        const ids = [];
        const errors = [];
        for (let i = 0; i < rows.length; i++) {
          const row = rows[i];
          const payload = {
            Account: row.Account,
            Date: row.Date,
            Amount: row.Amount,
            BankTransactionID: row.BankTransactionID || null,
            Description: row.Description ?? '',
          };
          try {
            const id = await items.createOne(payload);
            ids.push(id);
          } catch (err) {
            errors.push({ index: i, message: err?.message || String(err), row });
          }
        }

        return res.json({
          dryRun: false,
          count: rows.length,
          created: ids.length,
          ids,
          errors,
        });
      } catch (err) {
        next(err);
      }
    });
  },
};
