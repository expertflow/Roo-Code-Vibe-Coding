export default {
	id: 'cash-flow-api',
	handler: (router, { database }) => {

		const requireAuth = (req, res) => {
			const userId = req.accountability?.user;
			if (!userId) {
				res.status(403).json({
					errors: [{
						message: "You don't have permission to access this. Authenticated user required.",
						extensions: { code: "FORBIDDEN" }
					}]
				});
				return null;
			}
			return userId;
		};

		const fetchView = async (database, viewName, userId) => {
			return await database.transaction(async (trx) => {
				await trx.raw(`SET LOCAL ROLE directus_rls_subject`);
				await trx.raw(`SELECT set_config('directus.user_id', ?, true)`, [userId]);
				const data = await trx.raw(`SELECT * FROM "BS4Prod09Feb2026"."${viewName}"`);
				return data.rows;
			});
		};

		// Original cash_flow_report endpoint
		router.get('/', async (req, res) => {
			try {
				const userId = requireAuth(req, res);
				if (!userId) return;
				const results = await fetchView(database, 'cash_flow_report', userId);
				return res.json({ data: results });
			} catch (err) {
				console.error('[Cash Flow API Endpoint Error]', err);
				return res.status(500).json({ errors: [{ message: "Internal server error: " + err.message, extensions: { code: "INTERNAL_SERVER_ERROR" } }] });
			}
		});

		// Monthly cash flow summary for Lovable frontend
		router.get('/monthly', async (req, res) => {
			try {
				const userId = requireAuth(req, res);
				if (!userId) return;
				const results = await fetchView(database, 'lovable_monthly_cash_flow', userId);
				return res.json({ data: results });
			} catch (err) {
				console.error('[Cash Flow API /monthly Error]', err);
				return res.status(500).json({ errors: [{ message: "Internal server error: " + err.message, extensions: { code: "INTERNAL_SERVER_ERROR" } }] });
			}
		});

		// Past transactions for Lovable frontend
		router.get('/past-transactions', async (req, res) => {
			try {
				const userId = requireAuth(req, res);
				if (!userId) return;
				const results = await fetchView(database, 'lovable_past_transactions', userId);
				return res.json({ data: results });
			} catch (err) {
				console.error('[Cash Flow API /past-transactions Error]', err);
				return res.status(500).json({ errors: [{ message: "Internal server error: " + err.message, extensions: { code: "INTERNAL_SERVER_ERROR" } }] });
			}
		});
	}
};
