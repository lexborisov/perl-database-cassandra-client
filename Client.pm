package Database::Cassandra::Client;

use utf8;
use strict;
use vars qw($AUTOLOAD $VERSION $ABSTRACT @ISA @EXPORT);

BEGIN {
	$VERSION = 0.41;
	$ABSTRACT = "Cassandra client (XS for libcassandra)";
	
	@ISA = qw(Exporter DynaLoader);
	@EXPORT = qw(
		CASS_CONSISTENCY_ANY CASS_CONSISTENCY_ONE CASS_CONSISTENCY_TWO CASS_CONSISTENCY_THREE
		CASS_CONSISTENCY_QUORUM CASS_CONSISTENCY_ALL CASS_CONSISTENCY_LOCAL_QUORUM CASS_CONSISTENCY_EACH_QUORUM
		CASS_CONSISTENCY_SERIAL CASS_CONSISTENCY_LOCAL_SERIAL CASS_CONSISTENCY_LOCAL_ONE
		
		CASS_VALUE_TYPE_UNKNOWN CASS_VALUE_TYPE_CUSTOM CASS_VALUE_TYPE_ASCII CASS_VALUE_TYPE_BIGINT
		CASS_VALUE_TYPE_BLOB CASS_VALUE_TYPE_BOOLEAN CASS_VALUE_TYPE_COUNTER CASS_VALUE_TYPE_DECIMAL
		CASS_VALUE_TYPE_DOUBLE CASS_VALUE_TYPE_FLOAT CASS_VALUE_TYPE_INT CASS_VALUE_TYPE_TEXT
		CASS_VALUE_TYPE_TIMESTAMP CASS_VALUE_TYPE_UUID CASS_VALUE_TYPE_VARCHAR CASS_VALUE_TYPE_VARINT
		CASS_VALUE_TYPE_TIMEUUID CASS_VALUE_TYPE_INET CASS_VALUE_TYPE_LIST CASS_VALUE_TYPE_MAP CASS_VALUE_TYPE_SET
		
		CASS_COLLECTION_TYPE_LIST CASS_COLLECTION_TYPE_MAP CASS_COLLECTION_TYPE_SET
		CASS_BATCH_TYPE_LOGGED CASS_BATCH_TYPE_UNLOGGED CASS_BATCH_TYPE_COUNTER
		CASS_COMPRESSION_NONE CASS_COMPRESSION_SNAPPY CASS_COMPRESSION_LZ4
		CASS_LOG_DISABLED CASS_LOG_CRITICAL CASS_LOG_ERROR CASS_LOG_WARN CASS_LOG_INFO CASS_LOG_DEBUG CASS_LOG_LAST_ENTRY
		CASS_ERROR_SOURCE_NONE CASS_ERROR_SOURCE_LIB CASS_ERROR_SOURCE_SERVER CASS_ERROR_SOURCE_SSL CASS_ERROR_SOURCE_COMPRESSION
		
		CASS_OK CASS_ERROR_LIB_BAD_PARAMS CASS_ERROR_LIB_NO_STREAMS CASS_ERROR_LIB_UNABLE_TO_INIT CASS_ERROR_LIB_MESSAGE_ENCODE
		CASS_ERROR_LIB_HOST_RESOLUTION CASS_ERROR_LIB_UNEXPECTED_RESPONSE CASS_ERROR_LIB_REQUEST_QUEUE_FULL
		CASS_ERROR_LIB_NO_AVAILABLE_IO_THREAD CASS_ERROR_LIB_WRITE_ERROR CASS_ERROR_LIB_NO_HOSTS_AVAILABLE
		CASS_ERROR_LIB_INDEX_OUT_OF_BOUNDS CASS_ERROR_LIB_INVALID_ITEM_COUNT CASS_ERROR_LIB_INVALID_VALUE_TYPE
		CASS_ERROR_LIB_REQUEST_TIMED_OUT CASS_ERROR_LIB_UNABLE_TO_SET_KEYSPACE CASS_ERROR_LIB_CALLBACK_ALREADY_SET
		CASS_ERROR_INVALID_STATEMENT_TYPE CASS_ERROR_NAME_DOES_NOT_EXIST CASS_ERROR_UNABLE_TO_DETERMINE_PROTOCOL
		CASS_ERROR_LIB_NULL_VALUE CASS_ERROR_SERVER_SERVER_ERROR CASS_ERROR_SERVER_PROTOCOL_ERROR CASS_ERROR_SERVER_BAD_CREDENTIALS
		CASS_ERROR_SERVER_UNAVAILABLE CASS_ERROR_SERVER_OVERLOADED CASS_ERROR_SERVER_IS_BOOTSTRAPPING CASS_ERROR_SERVER_TRUNCATE_ERROR
		CASS_ERROR_SERVER_WRITE_TIMEOUT CASS_ERROR_SERVER_READ_TIMEOUT CASS_ERROR_SERVER_SYNTAX_ERROR CASS_ERROR_SERVER_UNAUTHORIZED
		CASS_ERROR_SERVER_INVALID_QUERY CASS_ERROR_SERVER_CONFIG_ERROR CASS_ERROR_SERVER_ALREADY_EXISTS CASS_ERROR_SERVER_UNPREPARED
		CASS_ERROR_SSL_CERT CASS_ERROR_SSL_CA_CERT CASS_ERROR_SSL_PRIVATE_KEY CASS_ERROR_SSL_CRL CASS_ERROR_LAST_ENTRY
	);
};

bootstrap Database::Cassandra::Client $VERSION;

use DynaLoader ();
use Exporter ();

1;


__END__

=head1 NAME

Database::Cassandra::Client - Cassandra client (XS for libcassandra)

=head1 SYNOPSIS

Simple API:

 use Database::Cassandra::Client;

 my $cass = Database::Cassandra::Client->cluster_new();
 
 my $status = $cass->sm_connect("node1.domainame.com,node2.domainame.com");
 die $cass->error_desc($status) if $status != CASS_OK;
 
 # insert
 {
 	my $sth = $cass->sm_prepare("INSERT INTO tw.docs (yauid, body) VALUES (?,?);", $status);
 	die $cass->error_desc($status) if $status != CASS_OK;
 	
 	$cass->statement_bind_int64($sth, 0, 1234567);
 	$cass->statement_bind_string($sth, 1, 'test body bind');
 	
 	$status = $cass->sm_execute_query($sth);
 	die $cass->error_desc($status) if $status != CASS_OK;
 }
 
 # get row
 {
 	my $sth = $cass->sm_prepare("SELECT * FROM tw.docs where yauid=1234567", $status);
 	die $cass->error_desc($status) if $status != CASS_OK;
 	
 	my $data = $cass->sm_select_query($sth, undef, $status);
 	die $cass->error_desc($status) if $status != CASS_OK;
 	
 	print $data->[0]->{yauid}, ": ", $data->[0]->{body}, "\n";
 }
 
 $cass->sm_destroy();


Base API:

 use Database::Cassandra::Client;
 
 my $status = CASS_OK;
 
 my $cass = Database::Cassandra::Client->cluster_new();
 
 $status = $cass->cluster_set_num_threads_io(4);
 warn $cass->error_desc($status) if $status != CASS_OK;
 
 $cass->cluster_set_contact_points("node1.domain.ru,node2.domain.ru");
 
 my $connect_future = $cass->cluster_connect();
 
 if(($status = $cass->future_error_code($connect_future)) == CASS_OK)
 {
 	my $session   = $cass->future_get_session($connect_future);
 
 	my $query     = $cass->string_init("select * from tw.docs limit 1");
 	my $statement = $cass->statement_new($query, 0);
 	
  	my $result_future = $cass->session_execute($session, $statement);
 	
	if(($status = $cass->future_error_code($result_future)) == CASS_OK)
	{
		my $result = $cass->future_get_result($result_future);
		my $rows   = $cass->iterator_from_result($result);
		
		while( $cass->iterator_next($rows) )
		{
			my $row   = $cass->iterator_get_row($rows);
			my $value = $cass->row_get_column($row, 1);
			# or my $value = $cass->row_get_column_by_name($row, "body");
			
			my $text = {};
			if(($status = $cass->value_get_string($value, $text)) == CASS_OK)
			{
				print $text, "\n";
			}
			else{ warn $cass->error_desc($status) }
		}
		
		$cass->result_free($result);
		$cass->iterator_free($rows);
	}
	
	$cass->statement_free($statement);
	$cass->future_free($result_future);
	
	my $close_future = $cass->session_close($session);
	$cass->future_wait($close_future);
	$cass->future_free($close_future);
 }
 else {die $cass->error_desc($status)}
 
 $cass->future_free($connect_future);
 $cass->cluster_free();
 

=head1 DESCRIPTION

This is glue for Cassandra C/C++ Driver library.

Please, before install this module make Cassandra library.

Current libcassandra 1.0 ( https://github.com/datastax/cpp-driver )

See https://github.com/datastax/cpp-driver


=head1 METHODS

=head2 simple

=head3 sm_connect

 my $error_code = $cass->sm_connect($contact_points);

Return: CASS_OK if successful, otherwise an error occurred

Example:

 my $cass = Database::Cassandra::Client->cluster_new();
 
 my $status = $cass->sm_connect("node1.domainame.com,node2.domainame.com");
 die $cass->error_desc($status) if $status != CASS_OK;


=head3 sm_prepare

 my $obj_Statement = $cass->sm_prepare($query, $out_status);

Return: obj_Statement

Example:

 my $status;
 my $sth = $cass->sm_prepare("INSERT INTO tw.docs (yauid, body) VALUES (12345,'test text')", $status);
 die $cass->error_desc($status) if $status != CASS_OK;


=head3 sm_execute_query

 my $error_code = $cass->sm_execute_query($statement);

Return: CASS_OK if successful, otherwise an error occurred

Example:

 my $cass = Database::Cassandra::Client->cluster_new();
 
 my $status = $cass->sm_connect("node1.domainame.com,node2.domainame.com");
 die $cass->error_desc($status) if $status != CASS_OK;
 
 my $sth = $cass->sm_prepare("INSERT INTO tw.docs (yauid, body) VALUES (?,?);", $status);
 die $cass->error_desc($status) if $status != CASS_OK;
 
 $cass->statement_bind_int64($sth, 0, 1234567);
 $cass->statement_bind_string($sth, 1, 'test body bind');
 
 $status = $cass->sm_execute_query($sth);
 die $cass->error_desc($status) if $status != CASS_OK;
 
 $cass->sm_destroy();


=head3 sm_select_query

 my $res = $cass->sm_select_query($statement, $binds, $out_status);

Return: variable

Example:

 my $cass = Database::Cassandra::Client->cluster_new();
 
 my $status = $cass->sm_connect("node1.domainame.com,node2.domainame.com");
 die $cass->error_desc($status) if $status != CASS_OK;

 my $sth = $cass->sm_prepare("SELECT * FROM tw.docs where yauid=?", $status);
 die $cass->error_desc($status) if $status != CASS_OK;
 
 $cass->statement_bind_int64($sth, 0, 1234567);
 
 my $data = $cass->sm_select_query($sth, undef, $status);
 die $cass->error_desc($status) if $status != CASS_OK;
 
 $cass->sm_destroy();


=head3 sm_destroy

 $cass->sm_destroy();

Return: undef


=head2 Cluster

=head3 cluster_new

 my $cassandra_object = cluster_new($name);

Creates a new cluster. 

Return: cassandra_object


=head3 cluster_free

 $cass->cluster_free();

Frees a cluster instance. 

Return: undef


=head3 cluster_set_contact_points

 my $error_code = $cass->cluster_set_contact_points($contact_points);

Sets/Appends contact points. This *MUST* be set. The first call sets the contact points and any subsequent calls appends additional contact points. Passing an empty string will clear the contact points. White space is striped from the contact points.  Examples: "127.0.0.1" "127.0.0.1,127.0.0.2", "server1.domain.com" 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_port

 my $error_code = $cass->cluster_set_port($port);

Sets the port.  Default: 9042 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_protocol_version

 my $error_code = $cass->cluster_set_protocol_version($protocol_version);

Sets the protocol version. This will automatically downgrade if to protocol version 1.  Default: 2 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_num_threads_io

 my $error_code = $cass->cluster_set_num_threads_io($num_threads);

Sets the number of IO threads. This is the number of threads that will handle query requests.  Default: 0 (creates a thread per core) 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_queue_size_io

 my $error_code = $cass->cluster_set_queue_size_io($queue_size);

Sets the size of the the fixed size queue that stores pending requests.  Default: 4096 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_core_connections_per_host

 my $error_code = $cass->cluster_set_core_connections_per_host($num_connections);

Sets the number of connections made to each server in each IO thread.  Default: 2 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_max_connections_per_host

 my $error_code = $cass->cluster_set_max_connections_per_host($num_connections);

Sets the maximum number of connections made to each server in each IO thread.  Default: 4 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_max_concurrent_creation

 my $error_code = $cass->cluster_set_max_concurrent_creation($num_connections);

Sets the maximum number of connections that will be created concurrently. Connections are created when the current connections are unable to keep up with request throughput.  Default: 1 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_max_concurrent_requests_threshold

 my $error_code = $cass->cluster_set_max_concurrent_requests_threshold($num_requests);

Sets the threshold for the maximum number of concurrent requests in-flight on a connection before creating a new connection. The number of new connections created will not exceed max_connections_per_host.  Default: 100 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_pending_requests_high_water_mark

 my $error_code = $cass->cluster_set_pending_requests_high_water_mark($num_requests);

Sets the high water mark for the number of requests queued waiting for a connection in a connection pool. Disables writes to a host on an IO worker if the number of requests queued exceed this value.  Default: 128 * max_connections_per_host 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_pending_requests_low_water_mark

 my $error_code = $cass->cluster_set_pending_requests_low_water_mark($num_requests);

Sets the low water mark for the number of requests queued waiting for a connection in a connection pool. After exceeding high water mark requests, writes to a host will only resume once the number of requests fall below this value.  Default: 64 * max_connections_per_host 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_connect_timeout

 my $error_code = $cass->cluster_set_connect_timeout($timeout);

Sets the timeout for connecting to a node.  Default: 5000 milliseconds 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_request_timeout

 my $error_code = $cass->cluster_set_request_timeout($timeout);

Sets the timeout for waiting for a response from a node.  Default: 12000 milliseconds 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_log_level

 my $error_code = $cass->cluster_set_log_level($level);

Sets the log level.  Default: CASS_LOG_WARN 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_log_callback

 my $error_code = $cass->cluster_set_log_callback($callback, $data);

Sets a callback for handling logging events.  Default: An internal callback that prints to stdout 

Return: CASS_OK if successful, otherwise an error occurred

Example:

 my $cass = Database::Cassandra::Client->cluster_new();
 
 my $callback = sub {
 	my ($time_uint64, $severity, $message, $arg) = @_;
 	print "[", $cass->log_level_string($severity), "] $message\n";
 };
 
 my $error_code = $cass->cluster_set_log_callback($callback, "arg data :D");



=head3 cluster_set_credentials

 my $error_code = $cass->cluster_set_credentials($username, $password);

Sets credentials for plain text authentication. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_load_balance_round_robin

 my $error_code = $cass->cluster_set_load_balance_round_robin();

Configures the cluster to use round-robin load balancing. This is the default, and does not need to be called unless switching an existing from another policy.  The driver discovers all nodes in a cluster and cycles through them per request. All are considered 'local'. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_set_load_balance_dc_aware

 my $error_code = $cass->cluster_set_load_balance_dc_aware($local_dc);

Configures the cluster to use DC-aware load balancing. For each query, all live nodes in a primary 'local' DC are tried first, followed by any node from other DCs. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 cluster_connect

 my $obj_Future = $cass->cluster_connect();

Connects a session to the cluster. 

Return: obj_Future


=head3 cluster_connect_keyspace

 my $obj_Future = $cass->cluster_connect_keyspace($keyspace);

Connects a session to the cluster and sets the keyspace. 

Return: obj_Future


=head2 Session

=head3 session_close

 my $obj_Future = $cass->session_close($session);

Closes the session instance, outputs a close future which can be used to determine when the session has been terminated. This allows in-flight requests to finish. It is an error to call this method twice with the same session as it is freed after it terminates. 

Return: obj_Future


=head3 session_prepare

 my $obj_Future = $cass->session_prepare($session, $query);

Create a prepared statement. 

Return: obj_Future


=head3 session_execute

 my $obj_Future = $cass->session_execute($session, $statement);

Execute a query or bound statement. 

Return: obj_Future


=head3 session_execute_batch

 my $obj_Future = $cass->session_execute_batch($session, $batch);

Execute a batch statement. 

Return: obj_Future


=head2 Future

=head3 future_free

 $cass->future_free($future);

Frees a future instance. A future can be freed anytime.

Return: undef


=head3 future_set_callback

 my $error_code = $cass->future_set_callback($future, $callback, $data);

Sets a callback that is called when a future is set 

Return: CASS_OK if successful, otherwise an error occurred


=head3 future_ready

 my $res = $cass->future_ready($future);

Gets the set status of the future. 

Return: variable


=head3 future_wait

 my $res = $cass->future_wait($future);

Wait for the future to be set with either a result or error. 

Return: variable


=head3 future_wait_timed

 my $res = $cass->future_wait_timed($future, $timeout);

Wait for the future to be set or timeout. 

Return: variable


=head3 future_get_session

 my $obj_Session = $cass->future_get_session($future);

Gets the result of a successful future. If the future is not ready this method will wait for the future to be set. The first successful call consumes the future, all subsequent calls will return NULL. 

Return: obj_Session


=head3 future_get_result

 my $obj_Result = $cass->future_get_result($future);

Gets the result of a successful future. If the future is not ready this method will wait for the future to be set. The first successful call consumes the future, all subsequent calls will return NULL. 

Return: obj_Result


=head3 future_get_prepared

 my $obj_Prepared = $cass->future_get_prepared($future);

Gets the result of a successful future. If the future is not ready this method will wait for the future to be set. The first successful call consumes the future, all subsequent calls will return NULL. 

Return: obj_Prepared


=head3 future_error_code

 my $error_code = $cass->future_error_code($future);

Gets the error code from future. If the future is not ready this method will wait for the future to be set. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 future_error_message

 my $res = $cass->future_error_message($future);

Gets the error message from future. If the future is not ready this method will wait for the future to be set. 

Return: variable


=head2 Statement

=head3 statement_new

 my $obj_Statement = $cass->statement_new($query, $parameter_count);

Creates a new query statement. 

Return: obj_Statement


=head3 statement_free

 $cass->statement_free($statement);

Frees a statement instance. Statements can be immediately freed after being prepared, executed or added to a batch. 

Return: undef


=head3 statement_set_consistency

 my $error_code = $cass->statement_set_consistency($statement, $consistency);

Sets the statement's consistency level.  Default: CASS_CONSISTENCY_ONE 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_set_serial_consistency

 my $error_code = $cass->statement_set_serial_consistency($statement, $serial_consistency);

Sets the statement's serial consistency level.  Default: Not set 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_set_paging_size

 my $error_code = $cass->statement_set_paging_size($statement, $page_size);

Sets the statement's page size.  Default: -1 (Disabled) 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_set_paging_state

 my $error_code = $cass->statement_set_paging_state($statement, $result);

Sets the statement's paging state. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_null

 my $error_code = $cass->statement_bind_null($statement, $index);

Binds null to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_int32

 my $error_code = $cass->statement_bind_int32($statement, $index, $value);

Binds an "int" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_int64

 my $error_code = $cass->statement_bind_int64($statement, $index, $value);

Binds a "bigint", "counter" or "timestamp" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_float

 my $error_code = $cass->statement_bind_float($statement, $index, $value);

Binds a "float" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_double

 my $error_code = $cass->statement_bind_double($statement, $index, $value);

Binds a "double" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_bool

 my $error_code = $cass->statement_bind_bool($statement, $index, $value);

Binds a "boolean" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_string

 my $error_code = $cass->statement_bind_string($statement, $index, $value);

Binds a "ascii", "text" or "varchar" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_bytes

 my $error_code = $cass->statement_bind_bytes($statement, $index, $value);

Binds a "blob" or "varint" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_uuid

 my $error_code = $cass->statement_bind_uuid($statement, $index, $value);

Binds a "uuid" or "timeuuid" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_inet

 my $error_code = $cass->statement_bind_inet($statement, $index, $value);

Binds an "inet" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_decimal

 my $error_code = $cass->statement_bind_decimal($statement, $index, $value);

Bind a "decimal" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_custom

 my $error_code = $cass->statement_bind_custom($statement, $index, $size, $output);

Binds any type to a query or bound statement at the specified index. A value can be copied into the resulting output buffer. This is normally reserved for large values to avoid extra memory copies. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_collection

 my $error_code = $cass->statement_bind_collection($statement, $index, $collection);

Bind a "list", "map", or "set" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_int32_by_name

 my $error_code = $cass->statement_bind_int32_by_name($statement, $name, $value);

Binds an "int" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_int64_by_name

 my $error_code = $cass->statement_bind_int64_by_name($statement, $name, $value);

Binds a "bigint", "counter" or "timestamp" to all values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_float_by_name

 my $error_code = $cass->statement_bind_float_by_name($statement, $name, $value);

Binds a "float" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_double_by_name

 my $error_code = $cass->statement_bind_double_by_name($statement, $name, $value);

Binds a "double" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_bool_by_name

 my $error_code = $cass->statement_bind_bool_by_name($statement, $name, $value);

Binds a "boolean" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_string_by_name

 my $error_code = $cass->statement_bind_string_by_name($statement, $name, $value);

Binds a "ascii", "text" or "varchar" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_bytes_by_name

 my $error_code = $cass->statement_bind_bytes_by_name($statement, $name, $value);

Binds a "blob" or "varint" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_uuid_by_name

 my $error_code = $cass->statement_bind_uuid_by_name($statement, $name, $value);

Binds a "uuid" or "timeuuid" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_inet_by_name

 my $error_code = $cass->statement_bind_inet_by_name($statement, $name, $value);

Binds an "inet" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_decimal_by_name

 my $error_code = $cass->statement_bind_decimal_by_name($statement, $name, $value);

Binds a "decimal" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_custom_by_name

 my $error_code = $cass->statement_bind_custom_by_name($statement, $name, $size, $output);

Binds any type to all the values with the specified name. A value can be copied into the resulting output buffer. This is normally reserved for large values to avoid extra memory copies.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head3 statement_bind_collection_by_name

 my $error_code = $cass->statement_bind_collection_by_name($statement, $name, $collection);

Bind a "list", "map", or "set" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


=head2 Prepared

=head3 prepared_free

 $cass->prepared_free($prepared);

Frees a prepared instance. 

Return: undef


=head3 prepared_bind

 my $obj_Statement = $cass->prepared_bind($prepared);

Creates a bound statement from a pre-prepared statement. 

Return: obj_Statement


=head2 Batch

=head3 batch_free

 $cass->batch_free($batch);

Frees a batch instance. Batches can be immediately freed after being executed. 

Return: undef


=head3 batch_set_consistency

 my $error_code = $cass->batch_set_consistency($batch, $consistency);

Sets the batch's consistency level 

Return: CASS_OK if successful, otherwise an error occurred


=head3 batch_add_statement

 my $error_code = $cass->batch_add_statement($batch, $statement);

Adds a statement to a batch. 

Return: CASS_OK if successful, otherwise an error occurred


=head2 Collection

=head3 collection_new

 my $obj_Collection = $cass->collection_new($type, $item_count);

Creates a new collection. 

Return: obj_Collection


=head3 collection_free

 $cass->collection_free($collection);

Frees a collection instance. 

Return: undef


=head3 collection_append_int32

 my $error_code = $cass->collection_append_int32($collection, $value);

Appends an "int" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 collection_append_int64

 my $error_code = $cass->collection_append_int64($collection, $value);

Appends a "bigint", "counter" or "timestamp" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 collection_append_float

 my $error_code = $cass->collection_append_float($collection, $value);

Appends a "float" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 collection_append_double

 my $error_code = $cass->collection_append_double($collection, $value);

Appends a "double" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 collection_append_bool

 my $error_code = $cass->collection_append_bool($collection, $value);

Appends a "boolean" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 collection_append_string

 my $error_code = $cass->collection_append_string($collection, $value);

Appends a "ascii", "text" or "varchar" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 collection_append_bytes

 my $error_code = $cass->collection_append_bytes($collection, $value);

Appends a "blob" or "varint" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 collection_append_uuid

 my $error_code = $cass->collection_append_uuid($collection, $value);

Appends a "uuid" or "timeuuid"  to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 collection_append_inet

 my $error_code = $cass->collection_append_inet($collection, $value);

Appends an "inet" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 collection_append_decimal

 my $error_code = $cass->collection_append_decimal($collection, $value);

Appends a "decimal" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


=head2 Result

=head3 result_free

 $cass->result_free($result);

Frees a result instance.  This method invalidates all values, rows, and iterators that were derived from this result. 

Return: undef


=head3 result_row_count

 my $res = $cass->result_row_count($result);

Gets the number of rows for the specified result. 

Return: variable


=head3 result_column_count

 my $res = $cass->result_column_count($result);

Gets the number of columns per row for the specified result. 

Return: variable


=head3 result_column_name

 my $res = $cass->result_column_name($result, $index);

Gets the column name at index for the specified result. 

Return: variable


=head3 result_column_type

 my $res = $cass->result_column_type($result, $index);

Gets the column type at index for the specified result. 

Return: variable


=head3 result_first_row

 my $obj_Row = $cass->result_first_row($result);

Gets the first row of the result. 

Return: obj_Row


=head3 result_has_more_pages

 my $res = $cass->result_has_more_pages($result);

Returns true if there are more pages. 

Return: variable


=head2 Iterator

=head3 iterator_free

 $cass->iterator_free($iterator);

Frees an iterator instance. 

Return: undef


=head3 iterator_from_result

 my $obj_Iterator = $cass->iterator_from_result($result);

Creates a new iterator for the specified result. This can be used to iterate over rows in the result. 

Return: obj_Iterator


=head3 iterator_from_row

 my $obj_Iterator = $cass->iterator_from_row($row);

Creates a new iterator for the specified row. This can be used to iterate over columns in a row. 

Return: obj_Iterator


=head3 iterator_from_collection

 my $obj_Iterator = $cass->iterator_from_collection($value);

Creates a new iterator for the specified collection. This can be used to iterate over values in a collection. 

Return: obj_Iterator


=head3 iterator_from_map

 my $obj_Iterator = $cass->iterator_from_map($value);

Creates a new iterator for the specified map. This can be used to iterate over key/value pairs in a map. 

Return: obj_Iterator


=head3 iterator_next

 my $res = $cass->iterator_next($iterator);

Advance the iterator to the next row, column, or collection item. 

Return: variable


=head3 iterator_get_row

 my $obj_Row = $cass->iterator_get_row($iterator);

Gets the row at the result iterator's current position.  Calling cass_iterator_next() will invalidate the previous row returned by this method. 

Return: obj_Row


=head3 iterator_get_column

 my $obj_Value = $cass->iterator_get_column($iterator);

Gets the column value at the row iterator's current position.  Calling cass_iterator_next() will invalidate the previous column returned by this method. 

Return: obj_Value


=head3 iterator_get_value

 my $obj_Value = $cass->iterator_get_value($iterator);

Gets the value at the collection iterator's current position.  Calling cass_iterator_next() will invalidate the previous value returned by this method. 

Return: obj_Value


=head3 iterator_get_map_key

 my $obj_Value = $cass->iterator_get_map_key($iterator);

Gets the key at the map iterator's current position.  Calling cass_iterator_next() will invalidate the previous value returned by this method. 

Return: obj_Value


=head3 iterator_get_map_value

 my $obj_Value = $cass->iterator_get_map_value($iterator);

Gets the value at the map iterator's current position.  Calling cass_iterator_next() will invalidate the previous value returned by this method. 

Return: obj_Value


=head2 Row

=head3 row_get_column

 my $obj_Value = $cass->row_get_column($row, $index);

Get the column value at index for the specified row. 

Return: obj_Value


=head3 row_get_column_by_name

 my $obj_Value = $cass->row_get_column_by_name($row, $name);

Get the column value by name for the specified row. 

Return: obj_Value


=head2 Value

=head3 value_get_int32

 my $error_code = $cass->value_get_int32($value, $output);

Gets an int32 for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 value_get_int64

 my $error_code = $cass->value_get_int64($value, $output);

Gets an int64 for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 value_get_float

 my $error_code = $cass->value_get_float($value, $output);

Gets a float for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 value_get_double

 my $error_code = $cass->value_get_double($value, $output);

Gets a double for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 value_get_bool

 my $error_code = $cass->value_get_bool($value, $output);

Gets a bool for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 value_get_uuid

 my $error_code = $cass->value_get_uuid($value, $output);

Gets a UUID for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 value_get_inet

 my $error_code = $cass->value_get_inet($value, $output);

Gets an INET for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 value_get_string

 my $error_code = $cass->value_get_string($value, $output);

Gets a string for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 value_get_bytes

 my $error_code = $cass->value_get_bytes($value, $output);

Gets the bytes of the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 value_get_decimal

 my $error_code = $cass->value_get_decimal($value, $output);

Gets a decimal for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


=head3 value_type

 my $res = $cass->value_type($value);

Gets the type of the specified value. 

Return: variable


=head3 value_is_null

 my $res = $cass->value_is_null($value);

Returns true if a specified value is null. 

Return: variable


=head3 value_primary_sub_type

 my $res = $cass->value_primary_sub_type($collection);

Get the primary sub-type for a collection. This returns the sub-type for a list or set and the key type for a map. 

Return: variable


=head3 value_secondary_sub_type

 my $res = $cass->value_secondary_sub_type($collection);

Get the secondary sub-type for a collection. This returns the value type for a map. 

Return: variable


=head2 UUID

=head3 uuid_generate_time

 $cass->uuid_generate_time($output);

Generates a V1 (time) UUID. 

Return: undef


=head3 uuid_from_time

 $cass->uuid_from_time($time, $output);

Generates a V1 (time) UUID for the specified time. 

Return: undef


=head3 uuid_min_from_time

 $cass->uuid_min_from_time($time, $output);

Generates a minimum V1 (time) UUID for the specified time. 

Return: undef


=head3 uuid_max_from_time

 $cass->uuid_max_from_time($time, $output);

Generates a maximum V1 (time) UUID for the specified time. 

Return: undef


=head3 uuid_generate_random

 $cass->uuid_generate_random($output);

Generates a new V4 (random) UUID 

Return: undef


=head3 uuid_timestamp

 my $res = $cass->uuid_timestamp($uuid);

Gets the timestamp for a V1 UUID 

Return: variable


=head3 uuid_version

 my $res = $cass->uuid_version($uuid);

Gets the version for a UUID 

Return: variable


=head3 uuid_string

 $cass->uuid_string($uuid, $output);

Returns a null-terminated string for the specified UUID. 

Return: undef


=head2 Error

=head3 error_desc

 my $res = $cass->error_desc($error_code);

Gets a description for an error code. 

Return: variable


=head2 Log level

=head3 log_level_string

 my $res = $cass->log_level_string($log_level);

Gets the string for a log level. 

Return: variable


=head2 Inet

=head3 inet_init_v4

 my $res = $cass->inet_init_v4($data);

Constructs an inet v4 object. 

Return: variable


=head3 inet_init_v6

 my $res = $cass->inet_init_v6($data);

Constructs an inet v6 object. 

Return: variable


=head2 Decimal

=head3 decimal_init

 my $res = $cass->decimal_init($scale, $varint);

Constructs a decimal object.  Note: This does not allocate memory. The object wraps the pointer passed into this function. 

Return: variable


=head2 Bytes/String

=head3 bytes_init

 my $res = $cass->bytes_init($data, $size);

Constructs a bytes object.  Note: This does not allocate memory. The object wraps the pointer passed into this function. 

Return: variable


=head3 string_init

 my $res = $cass->string_init($string);

Constructs a string object from a null-terminated string.  Note: This does not allocate memory. The object wraps the pointer passed into this function. 

Return: variable


=head3 string_init2

 my $res = $cass->string_init2($string, $length);

Constructs a string object.  Note: This does not allocate memory. The object wraps the pointer passed into this function. 

Return: variable


=head2 other

=head3 value_type_name_by_code

 my $res = $cass->value_type_name_by_code($vtype);

Return: variable


=head1 DESTROY

 undef $cass;

Free mem and destroy object.

=head1 AUTHOR

Alexander Borisov <lex.borisov@gmail.com>

https://github.com/lexborisov/perl-database-cassandra-client

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Alexander Borisov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

See libcassandra license and COPYRIGHT https://github.com/datastax/cpp-driver


=cut
