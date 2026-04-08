export default ({ filter, action }, { services, exceptions }) => {
	const { ItemsService } = services;
	const { InvalidPayloadError } = exceptions;

	filter('BankStatement.items.create', async (payload, meta, { schema, accountability }) => {
		if (payload.Transaction) {
			await validateLimit(payload.Transaction, schema, accountability);
		}
	});

	filter('BankStatement.items.update', async (payload, meta, { schema, accountability }) => {
		if (payload.Transaction) {
			await validateLimit(payload.Transaction, schema, accountability);
		}
	});

	async function validateLimit(transactionId, schema, accountability) {
		const service = new ItemsService('BankStatement', { schema, accountability });
		
		const count = await service.readByQuery({
			filter: {
				Transaction: { _eq: transactionId }
			},
			aggregate: {
				count: '*'
			}
		});

		const currentCount = parseInt(count[0].count);

		// Limit is 2 (ADR-05)
		if (currentCount >= 2) {
			throw new InvalidPayloadError('Transaction already matched to maximum (2) bank statements.');
		}
	}
};
