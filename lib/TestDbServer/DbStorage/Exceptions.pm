package Exception::DB;
use Moose;
with 'Throwable';

has sql => ( is => 'ro', isa => 'Str' );
has error => ( is => 'ro', isa => 'Str' );

package Exceptions::DB::CreateTable;
use Moose;
extends 'Exception::DB';

has table_name => ( is => 'ro', isa => 'Str' );

package Exception::DB::Select;
use Moose;
extends 'Exception::DB';

package Exception::DB::Select::Prepare;
use Moose;
extends 'Exception::DB::Select';

package Exception::DB::Select::Execute;
use Moose;
extends 'Exception::DB::Select';

package Exception::DB::Insert;
use Moose;
extends 'Exception::DB';

package Exception::DB::Insert::Prepare;
use Moose;
extends 'Exception::DB::Insert';

package Exception::DB::Insert::Execute;
use Moose;
extends 'Exception::DB::Insert';

package Exception::DB::Update;
use Moose;
extends 'Exception::DB';

package Exception::DB::Update::Prepare;
use Moose;
extends 'Exception::DB::Update';

package Exception::DB::Update::Execute;
use Moose;
extends 'Exception::DB::Update';

package Exception::DB::Delete;
use Moose;
extends 'Exception::DB';

package Exception::DB::Delete::Prepare;
use Moose;
extends 'Exception::DB::Delete';

package Exception::DB::Delete::Execute;
use Moose;
extends 'Exception::DB::Delete';

1;


