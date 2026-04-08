module.exports = ({ filter, action }, { services }) => {
	const { ItemsService } = services;
	filter('BankStatement.items.create', async (payload, meta, { schema, database, accountability }) => {
		await applySuggestions(payload, schema, database, accountability);
		return payload;
	});

	filter('BankStatement.items.update', async (payload, meta, { schema, database, accountability }) => {
		// Only re-run if key fields changed
		if ('Amount' in payload || 'Date' in payload) {
			await applySuggestions(payload, schema, database, accountability);
		}
		return payload;
	});

	async function applySuggestions(payload, schema, database, accountability) {
		const amount = payload.Amount;
		const dateStr = payload.Date;
		const accountId = payload.Account;

		if (amount === undefined || !dateStr) return;

		const absAmount = Math.abs(amount);
		const date = new Date(dateStr);

		const transactionService = new ItemsService('Transaction', { schema, knex: database, accountability: { admin: true } });
		const invoiceService = new ItemsService('Invoice', { schema, knex: database, accountability: { admin: true } });

		// 1. Heuristic Matching for Transaction (FR45.3)
		// ±5% amount, ±3 days
		const tMinAmount = absAmount * 0.95;
		const tMaxAmount = absAmount * 1.05;
		const tMinDate = new Date(date);
		tMinDate.setDate(tMinDate.getDate() - 5); // 5 days to account for weekends
		const tMaxDate = new Date(date);
		tMaxDate.setDate(tMaxDate.getDate() + 5);

		const [bestTransaction] = await transactionService.readByQuery({
			filter: {
				_and: [
					{ Amount: { _between: [tMinAmount, tMaxAmount] } },
					{ Date: { _between: [tMinDate.toISOString(), tMaxDate.toISOString()] } }
				]
			},
			limit: 1,
			sort: ['-Date']
		});

		if (bestTransaction) {
			payload.SuggestedTransaction = bestTransaction.id;
		}

		// 2. Heuristic Matching for Invoice (FR45.3)
		// ±10% amount, ±4 months
		const iMinAmount = absAmount * 0.90;
		const iMaxAmount = absAmount * 1.10;
		const iMinDate = new Date(date);
		iMinDate.setMonth(iMinDate.getMonth() - 4);
		const iMaxDate = new Date(date);
		iMaxDate.setMonth(iMaxDate.getMonth() + 4);

		// One leg must match the BankStatement's account
		// We filter by OriginAccount or DestinationAccount matching the BankStatement's Account
		const [bestInvoice] = await invoiceService.readByQuery({
			filter: {
				_and: [
					{ Amount: { _between: [iMinAmount, iMaxAmount] } },
					{
						_or: [
							{ SentDate: { _between: [iMinDate.toISOString(), iMaxDate.toISOString()] } },
							{ DueDate: { _between: [iMinDate.toISOString(), iMaxDate.toISOString()] } }
						]
					},
					{
						_or: [
							{ OriginAccount: { _eq: accountId } },
							{ DestinationAccount: { _eq: accountId } }
						]
					}
				]
			},
			limit: 1,
			sort: ['-SentDate']
		});

		if (bestInvoice) {
			payload.SuggestedInvoice = bestInvoice.id;
		}
	}
};
