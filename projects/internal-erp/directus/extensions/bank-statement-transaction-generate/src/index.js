export default {
	id: 'bank-statement-transaction-generate',
	handler: (router, { services, database, getSchema, logger, env }) => {
		const { ItemsService } = services;

		router.post('/run', async (req, res, next) => {
			try {
				// We enforce admin accountability for this endpoint's actions
				const accountability = { admin: true };

				const schema = await getSchema();

				const bankStatementService = new ItemsService('BankStatement', {
					knex: database,
					schema,
					accountability
				});

				const transactionService = new ItemsService('Transaction', {
					knex: database,
					schema,
					accountability
				});

				const baseFilter = {
					_and: [
						{ Transaction: { _null: true } },
						{ CorrespondantBank: { _nnull: true } },
						{ Project: { _nnull: true } }
					]
				};

				// req.body.keys will be populated if the user selected items before clicking the Flow button
				let keys = req.body?.keys;

				// Handle stringified arrays if passed (sometimes occurs with bad Flow payload interpolation)
				if (typeof keys === 'string') {
					try {
						const parsed = JSON.parse(keys);
						if (Array.isArray(parsed)) keys = parsed;
					} catch (e) {
						// Not a stringified array
					}
				}

				if (Array.isArray(keys)) {
					// Handle Flow trigger interpolating undefined to empty string or stringified arrays
					keys = keys.map(k => {
						if (typeof k === 'string' && k.startsWith('[') && k.endsWith(']')) {
							try { return JSON.parse(k); } catch(e) { return k; }
						}
						return k;
					}).flat();

					// Filter out empty values and convert to integers if they look like numbers
					keys = keys.filter(k => k !== null && k !== undefined && String(k).trim() !== "")
							   .map(k => isNaN(Number(k)) ? k : Number(k));
				}

				if (keys && Array.isArray(keys) && keys.length > 0) {
					baseFilter._and.push({ id: { _in: keys } });
				}

				const statements = await bankStatementService.readByQuery({
					filter: baseFilter,
					fields: [
						'id',
						'Amount',
						'Date',
						'Description',
						'Project',
						'Account.id',
						'Account.Currency',
						'CorrespondantBank'
					],
					limit: 500
				});

				const results = {
					processed: 0,
					foundExisting: 0,
					createdNew: 0,
					skipped: 0,
					errors: []
				};

				for (const statement of statements) {
					try {
						const amount = statement.Amount || 0;
						if (amount === 0) {
							results.skipped++;
							continue;
						}

						const absAmount = Math.abs(amount);
						// If amount > 0 (incoming), Origin = Account, Destination = CorrespondantBank
						// If amount < 0 (outgoing), Origin = CorrespondantBank, Destination = Account
						const originAccountId = amount > 0 ? statement.Account : statement.CorrespondantBank;
						const destAccountId = amount > 0 ? statement.CorrespondantBank : statement.Account;

						// In Directus relationship fields, Account could be integer ID or object.
						const originId = typeof originAccountId === 'object' ? originAccountId?.id : originAccountId;
						const destId = typeof destAccountId === 'object' ? destAccountId?.id : destAccountId;

						if (!originId || !destId) {
							throw new Error(`Missing account ID(s): Origin=${originId}, Dest=${destId}`);
						}

						if (originId === destId) {
							throw new Error(`Self-transfer detected: Origin and Destination are the same account (ID: ${originId}).`);
						}

						const currencyId = typeof statement.Account === 'object' ? statement.Account?.Currency : null;

						const statementDate = new Date(statement.Date);
						if (isNaN(statementDate.getTime())) {
							throw new Error(`Invalid statement date: ${statement.Date}`);
						}
						const minDate = new Date(statementDate);
						minDate.setDate(minDate.getDate() - 3);
						const maxDate = new Date(statementDate);
						maxDate.setDate(maxDate.getDate() + 3);

						const minDateStr = minDate.toISOString().split('T')[0];
						const maxDateStr = maxDate.toISOString().split('T')[0];

						const minAmt = absAmount * 0.95;
						const maxAmt = absAmount * 1.05;

						await database.transaction(async (trx) => {
							const transactionServiceTrx = new ItemsService('Transaction', {
								knex: trx,
								schema,
								accountability
							});

							const bankStatementServiceTrx = new ItemsService('BankStatement', {
								knex: trx,
								schema,
								accountability
							});

							// Search for existing Transaction
							const existingTransactions = await transactionServiceTrx.readByQuery({
								filter: {
									_and: [
										// Match absolute amount since we assume transactions record absolute values for standard transfers
										{ Amount: { _between: [minAmt, maxAmt] } },
										{ Date: { _between: [minDateStr, maxDateStr] } },
										{ OriginAccount: { _eq: originId } },
										{ DestinationAccount: { _eq: destId } }
									]
								},
								limit: 1,
								sort: ['-Date', 'id']
							});

							let transactionId;

							if (existingTransactions && existingTransactions.length > 0) {
								transactionId = existingTransactions[0].id;
								results.foundExisting++;
							} else {
								// Create a new Transaction
								const newTransaction = await transactionServiceTrx.createOne({
									Amount: absAmount,
									Date: statement.Date,
									Project: statement.Project,
									Description: statement.Description,
									OriginAccount: originId,
									DestinationAccount: destId,
									Currency: currencyId
								});
								transactionId = newTransaction;
								results.createdNew++;
							}

							// Link the Transaction back to the BankStatement
							await bankStatementServiceTrx.updateOne(statement.id, {
								Transaction: transactionId
							});
						});

						results.processed++;
					} catch (err) {
						logger?.error(`Error processing BankStatement ${statement.id}: ${err.message}`);
						results.errors.push({ id: statement.id, error: err.message });
					}
				}

				return res.json({
					success: true,
					...results
				});
			} catch (err) {
				logger?.error(err);
				next(err);
			}
		});
	}
};
