clean:
	psql -U postgres -h localhost -p 5434 -l | awk '{ if ($$3 =="genome") {  print $$1 } }' | xargs --no-run-if-empty -n1 dropdb -U postgres -h localhost -p 5434
	psql -U postgres -h localhost -p 5434 -c 'DROP DATABASE if exists test_db_master'
	createdb -U postgres -h localhost -p 5434 test_db_master
	( cd sqitch && sqitch deploy )

test: clean
	prove -l

