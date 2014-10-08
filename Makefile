genome_user:
	psql -U postgres -c 'DROP ROLE IF EXISTS genome'
	psql -U postgres -c 'CREATE ROLE genome WITH login'

remove_old_test_databases:
	psql -U postgres -l | awk '{ if ($$3 =="genome") {  print $$1 } }' | xargs --no-run-if-empty -n1 dropdb -U postgres

test_db_master:
	psql -U postgres -c 'DROP DATABASE if exists test_db_master'
	psql -U postgres -c 'create database test_db_master'

sqitch_deploy:
	( cd sqitch && sqitch deploy )

clean: remove_old_test_databases genome_user test_db_master sqitch_deploy

test: clean
	prove -l

.PHONY: genome_user remove_old_test_databases test_db_master sqitch_deploy clean test
