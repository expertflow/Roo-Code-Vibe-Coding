#!/bin/bash
sudo docker run --rm -v /tmp:/tmp --network host -e PGPASSWORD='06gttJSgZhbyhFkFb#DO' postgres:alpine psql -h 127.0.0.1 -p 5432 -U bs4_dev -d bidstruct4 -f /tmp/check_bs_rls.sql
