<template>
  <private-view title="Bank statement import">
    <template #title-outer:append>
      <span v-if="registryHint" class="registry-chip">{{ registryHint }}</span>
    </template>

    <div class="content">
      <p class="type-label" style="margin-bottom: 1rem">
        Upload a UBS e-banking CSV and choose which <strong>Account</strong> it belongs to. This uses the same Python
        parser as the CLI and <code>POST /bank-statement-import/run</code>.
      </p>

      <div class="links">
        <router-link to="/admin/content/BankStatement">Open BankStatement collection</router-link>
      </div>

      <div class="form">
        <div class="field">
          <div class="type-label">Account</div>
          <select v-model.number="accountId" class="account-select" :disabled="loadingAccounts">
            <option :value="null" disabled>Select an account…</option>
            <option v-for="a in accounts" :key="a.id" :value="a.id">{{ formatAccount(a) }}</option>
          </select>
          <span v-if="accountsError" class="error">{{ accountsError }}</span>
        </div>

        <div class="field">
          <div class="type-label">CSV file</div>
          <input type="file" accept=".csv,text/csv,text/plain" :disabled="loading" @change="onFile" />
        </div>

        <div class="field row">
          <label class="dry-run">
            <input v-model="dryRun" type="checkbox" :disabled="loading" />
            <span>Dry run (preview only, no rows created)</span>
          </label>
        </div>

        <div class="actions">
          <v-button :loading="loading" :disabled="!canSubmit" @click="submit">
            {{ dryRun ? 'Preview import' : 'Import to Directus' }}
          </v-button>
        </div>

        <p v-if="hint" class="hint">{{ hint }}</p>

        <div v-if="errorMsg" class="error block">{{ errorMsg }}</div>

        <div v-if="resultText" class="result">
          <div class="type-label">Response</div>
          <pre>{{ resultText }}</pre>
        </div>
      </div>
    </div>
  </private-view>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { useApi } from '@directus/extensions-sdk';

const api = useApi();

const accounts = ref([]);
const accountId = ref(null);
const file = ref(null);
const dryRun = ref(true);
const loading = ref(false);
const loadingAccounts = ref(true);
const accountsError = ref('');
const errorMsg = ref('');
const resultText = ref('');

const registryHint = 'Registered importers: accounts 7, 8, 9 (UBS) — others may error';

const canSubmit = computed(() => accountId.value != null && file.value != null && !loading.value);

const hint = computed(() => {
  if (!accountId.value) return '';
  if ([7, 8, 9].includes(Number(accountId.value))) return '';
  return 'This account is not in the bank-import registry (7/8/9). The server will return an error unless you add it to registry.json.';
});

function formatAccount(a) {
  const name = a.Name || `Account ${a.id}`;
  return `${name} (id ${a.id})`;
}

function onFile(ev) {
  const f = ev.target.files?.[0];
  file.value = f ?? null;
}

onMounted(async () => {
  loadingAccounts.value = true;
  accountsError.value = '';
  try {
    const { data } = await api.get('/items/Account', {
      params: {
        fields: ['id', 'Name'],
        sort: ['Name'],
        limit: -1,
      },
    });
    accounts.value = data?.data ?? [];
  } catch (e) {
    accountsError.value = e.response?.data?.errors?.[0]?.message || e.message || 'Failed to load accounts';
  } finally {
    loadingAccounts.value = false;
  }
});

async function submit() {
  if (!canSubmit.value) return;
  loading.value = true;
  errorMsg.value = '';
  resultText.value = '';
  try {
    const csv = await file.value.text();
    const { data } = await api.post('/bank-statement-import/run', {
      account: accountId.value,
      csv,
      dryRun: dryRun.value,
    });
    resultText.value = JSON.stringify(data, null, 2);
  } catch (e) {
    const body = e.response?.data;
    if (body?.error) {
      errorMsg.value = typeof body.error === 'string' ? body.error : JSON.stringify(body.error);
    } else if (body?.errors?.[0]?.message) {
      errorMsg.value = body.errors[0].message;
    } else {
      errorMsg.value = e.message || 'Request failed';
    }
    if (body) {
      resultText.value = JSON.stringify(body, null, 2);
    }
  } finally {
    loading.value = false;
  }
}
</script>

<style scoped>
.content {
  padding: var(--content-padding, 1.5rem);
  max-width: 52rem;
}
.links {
  margin-bottom: 1.25rem;
}
.form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
.field.row {
  flex-direction: row;
  align-items: center;
}
.field {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}
.account-select {
  max-width: 28rem;
  padding: 0.5rem 0.65rem;
  border-radius: var(--border-radius, 4px);
  border: var(--border-width, 1px) solid var(--border-normal, #ccc);
  background: var(--background-page, #fff);
  color: var(--foreground, #111);
}
.dry-run {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}
.actions {
  margin-top: 0.25rem;
}
.hint {
  color: var(--warning-125, #b8860b);
  font-size: 0.875rem;
}
.error {
  color: var(--danger, #c00);
}
.error.block {
  white-space: pre-wrap;
}
.registry-chip {
  display: inline-block;
  margin-inline-start: 0.5rem;
  padding: 0.15rem 0.5rem;
  font-size: 0.75rem;
  border-radius: var(--border-radius, 4px);
  background: var(--background-normal, #e8e8e8);
  color: var(--foreground-subdued, #444);
}
.result pre {
  margin-top: 0.35rem;
  padding: 1rem;
  overflow: auto;
  max-height: 28rem;
  font-size: 0.8rem;
  border-radius: var(--border-radius, 4px);
  border: var(--border-width, 1px) solid var(--border-normal, #ccc);
  background: var(--background-subdued, #f5f5f5);
}
</style>
