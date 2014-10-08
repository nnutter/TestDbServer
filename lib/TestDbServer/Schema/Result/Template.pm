package TestDbServer::Schema::Result::Template;
use parent 'DBIx::Class::Core';

__PACKAGE__->table('db_template');
__PACKAGE__->add_columns(qw(template_id name note owner sql_script create_time last_used_time));
__PACKAGE__->set_primary_key('template_id');
__PACKAGE__->has_many(databases => 'TestDbServer::Schema::Result::Database', 'template_id');

1;
