package TestDbServer::Schema::Result::DatabaseTemplate;
use parent 'DBIx::Class::Core';

__PACKAGE__->table('database_template');
__PACKAGE__->add_columns(qw(template_id host port name owner note create_time last_used_time));
__PACKAGE__->set_primary_key('template_id');

1;
