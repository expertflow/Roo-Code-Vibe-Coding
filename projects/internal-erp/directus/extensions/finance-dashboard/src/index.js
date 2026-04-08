import { defineModule } from '@directus/extensions-sdk';
import ModulePage from './module.vue';

export default defineModule({
    id: 'finance-dashboard',
    name: 'Finance/Executive',
    icon: 'payments',
    routes: [
        {
            path: '',
            component: ModulePage,
        },
    ],
});
