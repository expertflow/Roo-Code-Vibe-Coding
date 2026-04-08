import { defineModule } from '@directus/extensions-sdk';
import ModulePage from './module.vue';

export default defineModule({
  id: 'bank-statement-import-ui',
  name: 'Bank import',
  icon: 'upload_file',
  routes: [
    {
      path: '',
      component: ModulePage,
    },
  ],
});
