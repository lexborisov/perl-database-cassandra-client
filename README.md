perl-database-cassandra-client
==============================

Database::Cassandra::Client - Cassandra client (XS for libcassandra version 2.0.x)

# INSTALLATION

Please, before install this module make Cassandra library version 2.0.x.

See https://github.com/datastax/cpp-driver/tree/2.0

For version 1.0.x see https://github.com/lexborisov/perl-database-cassandra-client/tree/cpp_driver_1.0

Make module:

```sh
perl Makefile.PL
make
make test
make install
```

# SYNOPSIS

Simple API:

```perl
 use Database::Cassandra::Client;

 my $cass = Database::Cassandra::Client->cluster_new();
 $cass->cluster_set_num_threads_io(1);
 
 my $status = $cass->sm_connect("node1.domainame.com,node2.domainame.com");
 die $cass->error_desc($status) if $status != CASS_OK;
 
 # insert
 {
 	my $sth = $cass->sm_prepare("INSERT INTO tw.docs (yauid, body) VALUES (?,?);", $status);
 	die $cass->error_desc($status) if $status != CASS_OK;
 	
	for my $id (1..15)
	{
		$cass->statement_bind_int64($sth, 0, $id);
		$cass->statement_bind_string($sth, 1, "test body bind: $id");
		
		$status = $cass->sm_execute_query($sth);
		die $cass->error_desc($status) if $status != CASS_OK;
	}
	
	$cass->sm_finish_query($sth);
 }
 
 # get row
 {
 	my $sth = $cass->sm_prepare("SELECT * FROM tw.docs where yauid=?", $status);
 	die $cass->error_desc($status) if $status != CASS_OK;
 	
	for my $id (1..15)
	{
		$cass->statement_bind_int64($sth, 0, $id);
		
		my $data = $cass->sm_select_query($sth, undef, $status);
		die $cass->error_desc($status) if $status != CASS_OK;
		
		print $data->[0]->{yauid}, ": ", $data->[0]->{body}, "\n"
			if ref $data && exists $data->[0];
 	}
	
	$cass->sm_finish_query($sth);
 }
 
 $cass->sm_destroy();
```

Base API:

```perl
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
```

# DESCRIPTION

This is glue for Cassandra C/C++ Driver library.


# METHODS

## simple

### sm_connect

```perl
 my $error_code = $cass->sm_connect($contact_points);
```

Return: CASS_OK if successful, otherwise an error occurred

Example:

```perl
 my $cass = Database::Cassandra::Client->cluster_new();
 
 my $status = $cass->sm_connect("node1.domainame.com,node2.domainame.com");
 die $cass->error_desc($status) if $status != CASS_OK;
```

### sm_prepare

```perl
 my $obj_Statement = $cass->sm_prepare($query, $out_status);
```

Return: obj_Statement

Example:

```perl
 my $status;
 my $sth = $cass->sm_prepare("INSERT INTO tw.docs (yauid, body) VALUES (12345,'test text')", $status);
 die $cass->error_desc($status) if $status != CASS_OK;
 
 $cass->sm_finish_query($sth);
```


### sm_execute_query

```perl
 my $error_code = $cass->sm_execute_query($statement);
```

Return: CASS_OK if successful, otherwise an error occurred

Example:

```perl
 my $cass = Database::Cassandra::Client->cluster_new();
 
 my $status = $cass->sm_connect("node1.domainame.com,node2.domainame.com");
 die $cass->error_desc($status) if $status != CASS_OK;
 
 my $sth = $cass->sm_prepare("INSERT INTO tw.docs (yauid, body) VALUES (?,?);", $status);
 die $cass->error_desc($status) if $status != CASS_OK;
 
 $cass->statement_bind_int64($sth, 0, 1234567);
 $cass->statement_bind_string($sth, 1, 'test body bind');
 
 $status = $cass->sm_execute_query($sth);
 die $cass->error_desc($status) if $status != CASS_OK;
 
 $cass->sm_finish_query($sth);
 $cass->sm_destroy();
```


### sm_select_query

```perl
 my $res = $cass->sm_select_query($statement, $binds, $out_status);
```

Return: variable

Example:

```perl
 my $cass = Database::Cassandra::Client->cluster_new();
 
 my $status = $cass->sm_connect("node1.domainame.com,node2.domainame.com");
 die $cass->error_desc($status) if $status != CASS_OK;

 my $sth = $cass->sm_prepare("SELECT * FROM tw.docs where yauid=?", $status);
 die $cass->error_desc($status) if $status != CASS_OK;
 
 $cass->statement_bind_int64($sth, 0, 1234567);
 
 my $data = $cass->sm_select_query($sth, undef, $status);
 die $cass->error_desc($status) if $status != CASS_OK;
 
 $cass->sm_finish_query($sth);
 $cass->sm_destroy();
```

### sm_finish_query

```perl
 $cass->sm_finish_query($sth);
```

Free query statement


### sm_destroy

```perl
 $cass->sm_destroy();
```

Return: undef


## Cluster

### cluster_new

```perl
 my $cassandra_object = cluster_new($name);
```

Creates a new cluster. 

Return: cassandra_object


### cluster_free

```perl
 $cass->cluster_free();
```

Frees a cluster instance. 

Return: undef


### cluster_set_contact_points

```perl
 my $error_code = $cass->cluster_set_contact_points($contact_points);
```

Sets/Appends contact points. This *MUST* be set. The first call sets the contact points and any subsequent calls appends additional contact points. Passing an empty string will clear the contact points. White space is striped from the contact points.  Examples: "127.0.0.1" "127.0.0.1,127.0.0.2", "server1.domain.com" 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_port

```perl
 my $error_code = $cass->cluster_set_port($port);
```

Sets the port.  Default: 9042 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_protocol_version

```perl
 my $error_code = $cass->cluster_set_protocol_version($protocol_version);
```

Sets the protocol version. This will automatically downgrade if to protocol version 1.  Default: 2 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_num_threads_io

```perl
 my $error_code = $cass->cluster_set_num_threads_io($num_threads);
```

Sets the number of IO threads. This is the number of threads that will handle query requests.  Default: 0 (creates a thread per core) 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_queue_size_io

```perl
 my $error_code = $cass->cluster_set_queue_size_io($queue_size);
```

Sets the size of the the fixed size queue that stores pending requests.  Default: 4096 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_core_connections_per_host

```perl
 my $error_code = $cass->cluster_set_core_connections_per_host($num_connections);
```

Sets the number of connections made to each server in each IO thread.  Default: 2 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_max_connections_per_host

```perl
 my $error_code = $cass->cluster_set_max_connections_per_host($num_connections);
```

Sets the maximum number of connections made to each server in each IO thread.  Default: 4 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_max_concurrent_creation

```perl
 my $error_code = $cass->cluster_set_max_concurrent_creation($num_connections);
```

Sets the maximum number of connections that will be created concurrently. Connections are created when the current connections are unable to keep up with request throughput.  Default: 1 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_max_concurrent_requests_threshold

```perl
 my $error_code = $cass->cluster_set_max_concurrent_requests_threshold($num_requests);
```

Sets the threshold for the maximum number of concurrent requests in-flight on a connection before creating a new connection. The number of new connections created will not exceed max_connections_per_host.  Default: 100 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_pending_requests_high_water_mark

```perl
 my $error_code = $cass->cluster_set_pending_requests_high_water_mark($num_requests);
```

Sets the high water mark for the number of requests queued waiting for a connection in a connection pool. Disables writes to a host on an IO worker if the number of requests queued exceed this value.  Default: 128 * max_connections_per_host 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_pending_requests_low_water_mark

```perl
 my $error_code = $cass->cluster_set_pending_requests_low_water_mark($num_requests);
```

Sets the low water mark for the number of requests queued waiting for a connection in a connection pool. After exceeding high water mark requests, writes to a host will only resume once the number of requests fall below this value.  Default: 64 * max_connections_per_host 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_connect_timeout

```perl
 my $error_code = $cass->cluster_set_connect_timeout($timeout);
```

Sets the timeout for connecting to a node.  Default: 5000 milliseconds 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_request_timeout

```perl
 my $error_code = $cass->cluster_set_request_timeout($timeout);
```

Sets the timeout for waiting for a response from a node.  Default: 12000 milliseconds 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_log_level

```perl
 my $error_code = $cass->cluster_set_log_level($level);
```

Sets the log level.  Default: CASS_LOG_WARN 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_log_callback

```perl
 my $error_code = $cass->cluster_set_log_callback($callback, $data);
```

Sets a callback for handling logging events.  Default: An internal callback that prints to stdout 

Return: CASS_OK if successful, otherwise an error occurred

Example:

```perl
 my $cass = Database::Cassandra::Client->cluster_new();
 
 my $callback = sub {
 	my ($time_uint64, $severity, $message, $arg) = @_;
 	print "[", $cass->log_level_string($severity), "] $message\n";
 };
 
 my $error_code = $cass->cluster_set_log_callback($callback, "arg data :D");
```

### cluster_set_credentials

```perl
 my $error_code = $cass->cluster_set_credentials($username, $password);
```

Sets credentials for plain text authentication. 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_load_balance_round_robin

```perl
 my $error_code = $cass->cluster_set_load_balance_round_robin();
```

Configures the cluster to use round-robin load balancing. This is the default, and does not need to be called unless switching an existing from another policy.  The driver discovers all nodes in a cluster and cycles through them per request. All are considered 'local'. 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_load_balance_dc_aware

```perl
 my $error_code = $cass->cluster_set_load_balance_dc_aware($local_dc);
```

Configures the cluster to use DC-aware load balancing. For each query, all live nodes in a primary 'local' DC are tried first, followed by any node from other DCs. 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_connect

```perl
 my $obj_Future = $cass->cluster_connect();
```

Connects a session to the cluster. 

Return: obj_Future


### cluster_connect_keyspace

```perl
 my $obj_Future = $cass->cluster_connect_keyspace($keyspace);
```

Connects a session to the cluster and sets the keyspace. 

Return: obj_Future


## Session

### session_close

```perl
 my $obj_Future = $cass->session_close($session);
```

Closes the session instance, outputs a close future which can be used to determine when the session has been terminated. This allows in-flight requests to finish. It is an error to call this method twice with the same session as it is freed after it terminates. 

Return: obj_Future


### session_prepare

```perl
 my $obj_Future = $cass->session_prepare($session, $query);
```

Create a prepared statement. 

Return: obj_Future


### session_execute

```perl
 my $obj_Future = $cass->session_execute($session, $statement);
```

Execute a query or bound statement. 

Return: obj_Future


### session_execute_batch

```perl
 my $obj_Future = $cass->session_execute_batch($session, $batch);
```

Execute a batch statement. 

Return: obj_Future


## Future

### future_free

```perl
 $cass->future_free($future);
```

Frees a future instance. A future can be freed anytime.

Return: undef


### future_set_callback

```perl
 my $error_code = $cass->future_set_callback($future, $callback, $data);
```

Sets a callback that is called when a future is set 

Return: CASS_OK if successful, otherwise an error occurred


### future_ready

```perl
 my $res = $cass->future_ready($future);
```

Gets the set status of the future. 

Return: variable


### future_wait

```perl
 my $res = $cass->future_wait($future);
```

Wait for the future to be set with either a result or error. 

Return: variable


### future_wait_timed

```perl
 my $res = $cass->future_wait_timed($future, $timeout);
```

Wait for the future to be set or timeout. 

Return: variable


### future_get_session

```perl
 my $obj_Session = $cass->future_get_session($future);
```

Gets the result of a successful future. If the future is not ready this method will wait for the future to be set. The first successful call consumes the future, all subsequent calls will return NULL. 

Return: obj_Session


### future_get_result

```perl
 my $obj_Result = $cass->future_get_result($future);
```

Gets the result of a successful future. If the future is not ready this method will wait for the future to be set. The first successful call consumes the future, all subsequent calls will return NULL. 

Return: obj_Result


### future_get_prepared

```perl
 my $obj_Prepared = $cass->future_get_prepared($future);
```

Gets the result of a successful future. If the future is not ready this method will wait for the future to be set. The first successful call consumes the future, all subsequent calls will return NULL. 

Return: obj_Prepared


### future_error_code

```perl
 my $error_code = $cass->future_error_code($future);
```

Gets the error code from future. If the future is not ready this method will wait for the future to be set. 

Return: CASS_OK if successful, otherwise an error occurred


### future_error_message

```perl
 my $res = $cass->future_error_message($future);
```

Gets the error message from future. If the future is not ready this method will wait for the future to be set. 

Return: variable


## Statement

### statement_new

```perl
 my $obj_Statement = $cass->statement_new($query, $parameter_count);
```

Creates a new query statement. 

Return: obj_Statement


### statement_free

```perl
 $cass->statement_free($statement);
```

Frees a statement instance. Statements can be immediately freed after being prepared, executed or added to a batch. 

Return: undef


### statement_set_consistency

```perl
 my $error_code = $cass->statement_set_consistency($statement, $consistency);
```

Sets the statement's consistency level.  Default: CASS_CONSISTENCY_ONE 

Return: CASS_OK if successful, otherwise an error occurred


### statement_set_serial_consistency

```perl
 my $error_code = $cass->statement_set_serial_consistency($statement, $serial_consistency);
```

Sets the statement's serial consistency level.  Default: Not set 

Return: CASS_OK if successful, otherwise an error occurred


### statement_set_paging_size

```perl
 my $error_code = $cass->statement_set_paging_size($statement, $page_size);
```

Sets the statement's page size.  Default: -1 (Disabled) 

Return: CASS_OK if successful, otherwise an error occurred


### statement_set_paging_state

```perl
 my $error_code = $cass->statement_set_paging_state($statement, $result);
```

Sets the statement's paging state. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_null

```perl
 my $error_code = $cass->statement_bind_null($statement, $index);
```

Binds null to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_int32

```perl
 my $error_code = $cass->statement_bind_int32($statement, $index, $value);
```

Binds an "int" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_int64

```perl
 my $error_code = $cass->statement_bind_int64($statement, $index, $value);
```

Binds a "bigint", "counter" or "timestamp" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_float

```perl
 my $error_code = $cass->statement_bind_float($statement, $index, $value);
```

Binds a "float" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_double

```perl
 my $error_code = $cass->statement_bind_double($statement, $index, $value);
```

Binds a "double" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_bool

```perl
 my $error_code = $cass->statement_bind_bool($statement, $index, $value);
```

Binds a "boolean" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_string

```perl
 my $error_code = $cass->statement_bind_string($statement, $index, $value);
```

Binds a "ascii", "text" or "varchar" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_bytes

```perl
 my $error_code = $cass->statement_bind_bytes($statement, $index, $value);
```

Binds a "blob" or "varint" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_uuid

```perl
 my $error_code = $cass->statement_bind_uuid($statement, $index, $value);
```

Binds a "uuid" or "timeuuid" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_inet

```perl
 my $error_code = $cass->statement_bind_inet($statement, $index, $value);
```

Binds an "inet" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_decimal

```perl
 my $error_code = $cass->statement_bind_decimal($statement, $index, $value);
```

Bind a "decimal" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_custom

```perl
 my $error_code = $cass->statement_bind_custom($statement, $index, $size, $output);
```

Binds any type to a query or bound statement at the specified index. A value can be copied into the resulting output buffer. This is normally reserved for large values to avoid extra memory copies. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_collection

```perl
 my $error_code = $cass->statement_bind_collection($statement, $index, $collection);
```

Bind a "list", "map", or "set" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_int32_by_name

```perl
 my $error_code = $cass->statement_bind_int32_by_name($statement, $name, $value);
```

Binds an "int" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_int64_by_name

```perl
 my $error_code = $cass->statement_bind_int64_by_name($statement, $name, $value);
```

Binds a "bigint", "counter" or "timestamp" to all values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_float_by_name

```perl
 my $error_code = $cass->statement_bind_float_by_name($statement, $name, $value);
```

Binds a "float" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_double_by_name

```perl
 my $error_code = $cass->statement_bind_double_by_name($statement, $name, $value);
```

Binds a "double" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_bool_by_name

```perl
 my $error_code = $cass->statement_bind_bool_by_name($statement, $name, $value);
```

Binds a "boolean" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_string_by_name

```perl
 my $error_code = $cass->statement_bind_string_by_name($statement, $name, $value);
```

Binds a "ascii", "text" or "varchar" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_bytes_by_name

```perl
 my $error_code = $cass->statement_bind_bytes_by_name($statement, $name, $value);
```

Binds a "blob" or "varint" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_uuid_by_name

```perl
 my $error_code = $cass->statement_bind_uuid_by_name($statement, $name, $value);
```

Binds a "uuid" or "timeuuid" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_inet_by_name

```perl
 my $error_code = $cass->statement_bind_inet_by_name($statement, $name, $value);
```

Binds an "inet" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_decimal_by_name

```perl
 my $error_code = $cass->statement_bind_decimal_by_name($statement, $name, $value);
```

Binds a "decimal" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_custom_by_name

```perl
 my $error_code = $cass->statement_bind_custom_by_name($statement, $name, $size, $output);
```

Binds any type to all the values with the specified name. A value can be copied into the resulting output buffer. This is normally reserved for large values to avoid extra memory copies.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_collection_by_name

```perl
 my $error_code = $cass->statement_bind_collection_by_name($statement, $name, $collection);
```

Bind a "list", "map", or "set" to all the values with the specified name.  This can only be used with statements created by cass_prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


## Prepared

### prepared_free

```perl
 $cass->prepared_free($prepared);
```

Frees a prepared instance. 

Return: undef


### prepared_bind

```perl
 my $obj_Statement = $cass->prepared_bind($prepared);
```

Creates a bound statement from a pre-prepared statement. 

Return: obj_Statement


## Batch

### batch_free

```perl
 $cass->batch_free($batch);
```

Frees a batch instance. Batches can be immediately freed after being executed. 

Return: undef


### batch_set_consistency

```perl
 my $error_code = $cass->batch_set_consistency($batch, $consistency);
```

Sets the batch's consistency level 

Return: CASS_OK if successful, otherwise an error occurred


### batch_add_statement

```perl
 my $error_code = $cass->batch_add_statement($batch, $statement);
```

Adds a statement to a batch. 

Return: CASS_OK if successful, otherwise an error occurred


## Collection

### collection_new

```perl
 my $obj_Collection = $cass->collection_new($type, $item_count);
```

Creates a new collection. 

Return: obj_Collection


### collection_free

```perl
 $cass->collection_free($collection);
```

Frees a collection instance. 

Return: undef


### collection_append_int32

```perl
 my $error_code = $cass->collection_append_int32($collection, $value);
```

Appends an "int" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_int64

```perl
 my $error_code = $cass->collection_append_int64($collection, $value);
```

Appends a "bigint", "counter" or "timestamp" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_float

```perl
 my $error_code = $cass->collection_append_float($collection, $value);
```

Appends a "float" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_double

```perl
 my $error_code = $cass->collection_append_double($collection, $value);
```

Appends a "double" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_bool

```perl
 my $error_code = $cass->collection_append_bool($collection, $value);
```

Appends a "boolean" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_string

```perl
 my $error_code = $cass->collection_append_string($collection, $value);
```

Appends a "ascii", "text" or "varchar" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_bytes

```perl
 my $error_code = $cass->collection_append_bytes($collection, $value);
```

Appends a "blob" or "varint" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_uuid

```perl
 my $error_code = $cass->collection_append_uuid($collection, $value);
```

Appends a "uuid" or "timeuuid"  to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_inet

```perl
 my $error_code = $cass->collection_append_inet($collection, $value);
```

Appends an "inet" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_decimal

```perl
 my $error_code = $cass->collection_append_decimal($collection, $value);
```

Appends a "decimal" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


## Result

### result_free

```perl
 $cass->result_free($result);
```

Frees a result instance.  This method invalidates all values, rows, and iterators that were derived from this result. 

Return: undef


### result_row_count

```perl
 my $res = $cass->result_row_count($result);
```

Gets the number of rows for the specified result. 

Return: variable


### result_column_count

```perl
 my $res = $cass->result_column_count($result);
```

Gets the number of columns per row for the specified result. 

Return: variable


### result_column_name

```perl
 my $res = $cass->result_column_name($result, $index);
```

Gets the column name at index for the specified result. 

Return: variable


### result_column_type

```perl
 my $res = $cass->result_column_type($result, $index);
```

Gets the column type at index for the specified result. 

Return: variable


### result_first_row

```perl
 my $obj_Row = $cass->result_first_row($result);
```

Gets the first row of the result. 

Return: obj_Row


### result_has_more_pages

```perl
 my $res = $cass->result_has_more_pages($result);
```

Returns true if there are more pages. 

Return: variable


## Iterator

### iterator_free

```perl
 $cass->iterator_free($iterator);
```

Frees an iterator instance. 

Return: undef


### iterator_from_result

```perl
 my $obj_Iterator = $cass->iterator_from_result($result);
```

Creates a new iterator for the specified result. This can be used to iterate over rows in the result. 

Return: obj_Iterator


### iterator_from_row

```perl
 my $obj_Iterator = $cass->iterator_from_row($row);
```

Creates a new iterator for the specified row. This can be used to iterate over columns in a row. 

Return: obj_Iterator


### iterator_from_collection

```perl
 my $obj_Iterator = $cass->iterator_from_collection($value);
```

Creates a new iterator for the specified collection. This can be used to iterate over values in a collection. 

Return: obj_Iterator


### iterator_from_map

```perl
 my $obj_Iterator = $cass->iterator_from_map($value);
```

Creates a new iterator for the specified map. This can be used to iterate over key/value pairs in a map. 

Return: obj_Iterator


### iterator_next

```perl
 my $res = $cass->iterator_next($iterator);
```

Advance the iterator to the next row, column, or collection item. 

Return: variable


### iterator_get_row

```perl
 my $obj_Row = $cass->iterator_get_row($iterator);
```

Gets the row at the result iterator's current position.  Calling cass_iterator_next() will invalidate the previous row returned by this method. 

Return: obj_Row


### iterator_get_column

```perl
 my $obj_Value = $cass->iterator_get_column($iterator);
```

Gets the column value at the row iterator's current position.  Calling cass_iterator_next() will invalidate the previous column returned by this method. 

Return: obj_Value


### iterator_get_value

```perl
 my $obj_Value = $cass->iterator_get_value($iterator);
```

Gets the value at the collection iterator's current position.  Calling cass_iterator_next() will invalidate the previous value returned by this method. 

Return: obj_Value


### iterator_get_map_key

```perl
 my $obj_Value = $cass->iterator_get_map_key($iterator);
```

Gets the key at the map iterator's current position.  Calling cass_iterator_next() will invalidate the previous value returned by this method. 

Return: obj_Value


### iterator_get_map_value

```perl
 my $obj_Value = $cass->iterator_get_map_value($iterator);
```

Gets the value at the map iterator's current position.  Calling cass_iterator_next() will invalidate the previous value returned by this method. 

Return: obj_Value


## Row

### row_get_column

```perl
 my $obj_Value = $cass->row_get_column($row, $index);
```

Get the column value at index for the specified row. 

Return: obj_Value


### row_get_column_by_name

```perl
 my $obj_Value = $cass->row_get_column_by_name($row, $name);
```

Get the column value by name for the specified row. 

Return: obj_Value


## Value

### value_get_int32

```perl
 my $error_code = $cass->value_get_int32($value, $output);
```

Gets an int32 for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_int64

```perl
 my $error_code = $cass->value_get_int64($value, $output);
```

Gets an int64 for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_float

```perl
 my $error_code = $cass->value_get_float($value, $output);
```

Gets a float for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_double

```perl
 my $error_code = $cass->value_get_double($value, $output);
```

Gets a double for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_bool

```perl
 my $error_code = $cass->value_get_bool($value, $output);
```

Gets a bool for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_uuid

```perl
 my $error_code = $cass->value_get_uuid($value, $output);
```

Gets a UUID for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_inet

```perl
 my $error_code = $cass->value_get_inet($value, $output);
```

Gets an INET for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_string

```perl
 my $error_code = $cass->value_get_string($value, $output);
```

Gets a string for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_bytes

```perl
 my $error_code = $cass->value_get_bytes($value, $output);
```

Gets the bytes of the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_decimal

```perl
 my $error_code = $cass->value_get_decimal($value, $output);
```

Gets a decimal for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_type

```perl
 my $res = $cass->value_type($value);
```

Gets the type of the specified value. 

Return: variable


### value_is_null

```perl
 my $res = $cass->value_is_null($value);
```

Returns true if a specified value is null. 

Return: variable


### value_primary_sub_type

```perl
 my $res = $cass->value_primary_sub_type($collection);
```

Get the primary sub-type for a collection. This returns the sub-type for a list or set and the key type for a map. 

Return: variable


### value_secondary_sub_type

```perl
 my $res = $cass->value_secondary_sub_type($collection);
```

Get the secondary sub-type for a collection. This returns the value type for a map. 

Return: variable


## UUID

### uuid_generate_time

```perl
 $cass->uuid_generate_time($output);
```

Generates a V1 (time) UUID. 

Return: undef


### uuid_from_time

```perl
 $cass->uuid_from_time($time, $output);
```

Generates a V1 (time) UUID for the specified time. 

Return: undef


### uuid_min_from_time

```perl
 $cass->uuid_min_from_time($time, $output);
```

Generates a minimum V1 (time) UUID for the specified time. 

Return: undef


### uuid_max_from_time

```perl
 $cass->uuid_max_from_time($time, $output);
```

Generates a maximum V1 (time) UUID for the specified time. 

Return: undef


### uuid_generate_random

```perl
 $cass->uuid_generate_random($output);
```

Generates a new V4 (random) UUID 

Return: undef


### uuid_timestamp

```perl
 my $res = $cass->uuid_timestamp($uuid);
```

Gets the timestamp for a V1 UUID 

Return: variable


### uuid_version

```perl
 my $res = $cass->uuid_version($uuid);
```

Gets the version for a UUID 

Return: variable


### uuid_string

```perl
 $cass->uuid_string($uuid, $output);
```

Returns a null-terminated string for the specified UUID. 

Return: undef


## Error

### error_desc

```perl
 my $res = $cass->error_desc($error_code);
```

Gets a description for an error code. 

Return: variable


## Log level

### log_level_string

```perl
 my $res = $cass->log_level_string($log_level);
```

Gets the string for a log level. 

Return: variable


## Inet

### inet_init_v4

```perl
 my $res = $cass->inet_init_v4($data);
```

Constructs an inet v4 object. 

Return: variable


### inet_init_v6

```perl
 my $res = $cass->inet_init_v6($data);
```

Constructs an inet v6 object. 

Return: variable


## Decimal

### decimal_init

```perl
 my $res = $cass->decimal_init($scale, $varint);
```

Constructs a decimal object.  Note: This does not allocate memory. The object wraps the pointer passed into this function. 

Return: variable


## Bytes/String

### bytes_init

```perl
 my $res = $cass->bytes_init($data, $size);
```

Constructs a bytes object.  Note: This does not allocate memory. The object wraps the pointer passed into this function. 

Return: variable


### string_init

```perl
 my $res = $cass->string_init($string);
```

Constructs a string object from a null-terminated string.  Note: This does not allocate memory. The object wraps the pointer passed into this function. 

Return: variable


### string_init2

```perl
 my $res = $cass->string_init2($string, $length);
```

Constructs a string object.  Note: This does not allocate memory. The object wraps the pointer passed into this function. 

Return: variable


## other

### value_type_name_by_code

```perl
 my $res = $cass->value_type_name_by_code($vtype);
```

Return: variable

# DESTROY

 undef $cass;

Free mem and destroy object.

# AUTHOR

Alexander Borisov <lex.borisov@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Alexander Borisov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

See libcassandra license and COPYRIGHT https://github.com/datastax/cpp-driver
