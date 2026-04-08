module.exports = ({ filter }, { services }) => {
	const { ItemsService } = services;

	filter('BankStatement.items.create', async (payload, meta, { schema, accountability }) => {
		// Only run if Description is provided and CorrespondantBank is not already manually set
		if (!payload.Description || payload.CorrespondantBank) return payload;

		// Extract first 20 characters
		const prefix = payload.Description.substring(0, 20);

		const service = new ItemsService('BankStatement', { schema, accountability: { admin: true } });

		// Find the newest existing BankStatement with the same prefix that has a CorrespondantBank
		const [match] = await service.readByQuery({
			filter: {
				_and: [
					{
						Description: {
							_starts_with: prefix
						}
					},
					{
						CorrespondantBank: {
							_nnull: true
						}
					}
				]
			},
			sort: ['-Date', '-id'],
			limit: 1
		});

		// If a match is found, copy the CorrespondantBank FK
		if (match && match.CorrespondantBank) {
			payload.CorrespondantBank = match.CorrespondantBank;
		}

		return payload;
	});
};
