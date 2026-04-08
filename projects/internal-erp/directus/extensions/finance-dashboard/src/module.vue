<template>
  <private-view title="Finance Dashboard">
    <template #header-actions>
      <v-button @click="fetchData" icon rounded :loading="loading">
        <v-icon name="refresh" />
      </v-button>
    </template>
    
    <div style="padding: var(--content-padding);">
      <v-notice v-if="error" type="danger" style="margin-bottom: 20px;">
        {{ error }}
      </v-notice>
      
      <div v-if="loading && rawData.length === 0" style="display: flex; justify-content: center; padding: 40px;">
        <v-progress-circular indeterminate />
      </div>

      <div v-else style="background: var(--background-page); padding: 20px; border-radius: var(--border-radius); border: var(--border-width) solid var(--border-normal);">
        <h2 style="margin-bottom: 20px; font-weight: 600;">Cash Flow Report (Realized vs Forecast)</h2>
        <div style="height: 600px; width: 100%;">
          <Bar v-if="chartData.labels.length" :data="chartData" :options="chartOptions" />
          <div v-else style="text-align: center; color: var(--foreground-subdued); padding: 40px;">
            No cash flow data available.
          </div>
        </div>
      </div>
    </div>
  </private-view>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { useApi } from '@directus/extensions-sdk';
import { Bar } from 'vue-chartjs';
import { Chart as ChartJS, Title, Tooltip, Legend, BarElement, CategoryScale, LinearScale } from 'chart.js';

ChartJS.register(Title, Tooltip, Legend, BarElement, CategoryScale, LinearScale);

const api = useApi();
const loading = ref(true);
const error = ref(null);
const rawData = ref([]);

const chartData = computed(() => {
  if (!rawData.value.length) return { labels: [], datasets: [] };

  const datesSet = new Set();
  rawData.value.forEach(d => {
    if (d.report_date) datesSet.add(d.report_date.split('T')[0]); // handle YYYY-MM-DD
  });
  
  const dates = [...datesSet].sort();
  
  const realized = dates.map(date => {
    const item = rawData.value.find(d => d.report_date && d.report_date.startsWith(date) && d.series_type === 'Realized');
    return item ? parseFloat(item.amount) : 0;
  });

  const forecast = dates.map(date => {
    const item = rawData.value.find(d => d.report_date && d.report_date.startsWith(date) && d.series_type === 'Forecast');
    return item ? parseFloat(item.amount) : 0;
  });

  return {
    labels: dates,
    datasets: [
      {
        label: 'Realized (Transactions)',
        backgroundColor: '#4ade80',
        data: realized
      },
      {
        label: 'Forecast (Invoices)',
        backgroundColor: '#60a5fa',
        data: forecast
      }
    ]
  };
});

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  scales: {
    y: {
      beginAtZero: true
    }
  }
};

async function fetchData() {
  try {
    loading.value = true;
    error.value = null;
    // limit=-1 gets all results, but it's better to fetch limited or handle pagination
    // Fetch robustly through our custom endpoint to bypass primary key limitations
    const response = await api.get('/cash-flow-api');
    rawData.value = response.data.data;
  } catch (err) {
    console.error('Error fetching cash flow report:', err);
    error.value = err.response?.data?.errors?.[0]?.message || err.message || 'Failed to fetch data';
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  fetchData();
});
</script>
