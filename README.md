perl-database-cassandra-client
==============================

Cassandra client (XS for libcassandra v1.0.x)

# INSTALLATION

Please, before install this module make Cassandra library v1.0.x

See https://github.com/datastax/cpp-driver/tree/1.0

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
 
 my $status = $cass->sm_connect("node1.domainame.com,node2.domainame.com");
 die $cass->error_desc($status) if $status != CASS_OK;
 
 # insert
 {
 	my $prepare = $cass->sm_prepare("INSERT INTO tw.docs (yauid, body) VALUES (?,?);", $status);
 	die $cass->error_desc($status) if $status != CASS_OK;
 	
	for my $id (1..15)
	{
		my $statement = $cass->prepared_bind($prepare);
		
		$cass->statement_bind_int64($statement, 0, $id);
		$cass->statement_bind_string($statement, 1, "test body bind: $id");
		
		$status = $cass->sm_execute_query($statement);
		die $cass->error_desc($status) if $status != CASS_OK;
		
		$cass->statement_free($statement);
	}
	
	$cass->sm_finish_query($prepare); # or $cass->prepared_free($prepare);
 }
 
 # get row
 {
 	my $prepare = $cass->sm_prepare("SELECT * FROM tw.docs where yauid=?", $status);
 	die $cass->error_desc($status) if $status != CASS_OK;
 	
	for my $id (1..15)
	{
		my $statement = $cass->prepared_bind($prepare);
		
		$cass->statement_bind_int64($statement, 0, $id);
		
		my $data = $cass->sm_select_query($statement, $status);
		die $cass->error_desc($status) if $status != CASS_OK;
		
		print $data->[0]->{yauid}, ": ", $data->[0]->{body}, "\n"
			if ref $data && exists $data->[0];
		
		$cass->statement_free($statement);
 	}
	
	$cass->sm_finish_query($prepare); # or $cass->prepared_free($prepare);
 }
 
 $cass->sm_destroy();
```


# DESCRIPTION

This is glue for Cassandra C/C++ Driver library version 1.0.x


# METHODS

## simple

### sm_connect

```perl
 my $int_CassError = $cass->sm_connect($contact_points);
```

Return: CASS_OK if successful, otherwise an error occurred


### sm_execute_query

```perl
 my $int_CassError = $cass->sm_execute_query($statement);
```

Return: CASS_OK if successful, otherwise an error occurred


### sm_execute_query_no_wait

```perl
 my $obj_CassFuture = $cass->sm_execute_query_no_wait($statement);
```

Return: obj_CassFuture


### sm_prepare

```perl
 my $obj_CassPrepared = $cass->sm_prepare($query, $out_status);
```

Return: obj_CassPrepared


### sm_select_query

```perl
 my $res = $cass->sm_select_query($statement, $out_status);
```

Return: variable


### sm_result_from_future

```perl
 my $res = $cass->sm_result_from_future($future, $out_status);
```

Return: variable


### sm_finish_query

```perl
 $cass->sm_finish_query($prepared);
```

Return: undef


### sm_destroy

```perl
 $cass->sm_destroy();
```

Return: undef


### sm_get_session

```perl
 my $obj_CassSession = $cass->sm_get_session();
```

Return: obj_CassSession


## base

## Cluster

### cluster_new

```perl
 my $cass = cluster_new($name);
```

Creates a new cluster. 

Return: cass


### cluster_free

```perl
 $cass->cluster_free();
```

Frees a cluster instance. 

Return: undef


### cluster_set_contact_points

```perl
 my $int_CassError = $cass->cluster_set_contact_points($contact_points);
```

Sets/Appends contact points. This *MUST* be set. The first call sets the contact points and any subsequent calls appends additional contact points. Passing an empty string will clear the contact points. White space is striped from the contact points.  Examples: "127.0.0.1" "127.0.0.1,127.0.0.2", "server1.domain.com" 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_port

```perl
 my $int_CassError = $cass->cluster_set_port($port);
```

Sets the port.  Default: 9042 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_ssl

```perl
 $cass->cluster_set_ssl($ssl);
```

Sets the SSL context and enables SSL. 

Return: undef


### cluster_set_protocol_version

```perl
 my $int_CassError = $cass->cluster_set_protocol_version($protocol_version);
```

Sets the protocol version. This will automatically downgrade if to protocol version 1.  Default: 2 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_num_threads_io

```perl
 $cass->cluster_set_num_threads_io($num_threads);
```

Sets the number of IO threads. This is the number of threads that will handle query requests.  Default: 1 

Return: undef


### cluster_set_queue_size_io

```perl
 my $int_CassError = $cass->cluster_set_queue_size_io($queue_size);
```

Sets the size of the the fixed size queue that stores pending requests.  Default: 4096 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_queue_size_event

```perl
 my $int_CassError = $cass->cluster_set_queue_size_event($queue_size);
```

Sets the size of the the fixed size queue that stores events.  Default: 4096 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_queue_size_log

```perl
 my $int_CassError = $cass->cluster_set_queue_size_log($queue_size);
```

Sets the size of the the fixed size queue that stores log messages.  Default: 4096 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_core_connections_per_host

```perl
 my $int_CassError = $cass->cluster_set_core_connections_per_host($num_connections);
```

Sets the number of connections made to each server in each IO thread.  Default: 1 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_max_connections_per_host

```perl
 my $int_CassError = $cass->cluster_set_max_connections_per_host($num_connections);
```

Sets the maximum number of connections made to each server in each IO thread.  Default: 2 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_reconnect_wait_time

```perl
 $cass->cluster_set_reconnect_wait_time($wait_time);
```

Sets the amount of time to wait before attempting to reconnect.  Default: 2000 milliseconds 

Return: undef


### cluster_set_max_concurrent_creation

```perl
 my $int_CassError = $cass->cluster_set_max_concurrent_creation($num_connections);
```

Sets the maximum number of connections that will be created concurrently. Connections are created when the current connections are unable to keep up with request throughput.  Default: 1 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_max_concurrent_requests_threshold

```perl
 my $int_CassError = $cass->cluster_set_max_concurrent_requests_threshold($num_requests);
```

Sets the threshold for the maximum number of concurrent requests in-flight on a connection before creating a new connection. The number of new connections created will not exceed max_connections_per_host.  Default: 100 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_max_requests_per_flush

```perl
 my $int_CassError = $cass->cluster_set_max_requests_per_flush($num_requests);
```

Sets the maximum number of requests processed by an IO worker per flush.  Default: 128 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_write_bytes_high_water_mark

```perl
 my $int_CassError = $cass->cluster_set_write_bytes_high_water_mark($num_bytes);
```

Sets the high water mark for the number of bytes outstanding on a connection. Disables writes to a connection if the number of bytes queued exceed this value.  Default: 64 KB 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_write_bytes_low_water_mark

```perl
 my $int_CassError = $cass->cluster_set_write_bytes_low_water_mark($num_bytes);
```

Sets the low water mark for number of bytes outstanding on a connection. After exceeding high water mark bytes, writes will only resume once the number of bytes fall below this value.  Default: 32 KB 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_pending_requests_high_water_mark

```perl
 my $int_CassError = $cass->cluster_set_pending_requests_high_water_mark($num_requests);
```

Sets the high water mark for the number of requests queued waiting for a connection in a connection pool. Disables writes to a host on an IO worker if the number of requests queued exceed this value.  Default: 128 * max_connections_per_host 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_pending_requests_low_water_mark

```perl
 my $int_CassError = $cass->cluster_set_pending_requests_low_water_mark($num_requests);
```

Sets the low water mark for the number of requests queued waiting for a connection in a connection pool. After exceeding high water mark requests, writes to a host will only resume once the number of requests fall below this value.  Default: 64 * max_connections_per_host 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_connect_timeout

```perl
 $cass->cluster_set_connect_timeout($timeout_ms);
```

Sets the timeout for connecting to a node.  Default: 5000 milliseconds 

Return: undef


### cluster_set_request_timeout

```perl
 $cass->cluster_set_request_timeout($timeout_ms);
```

Sets the timeout for waiting for a response from a node.  Default: 12000 milliseconds 

Return: undef


### cluster_set_credentials

```perl
 $cass->cluster_set_credentials($username, $password);
```

Sets credentials for plain text authentication. 

Return: undef


### cluster_set_load_balance_round_robin

```perl
 $cass->cluster_set_load_balance_round_robin();
```

Configures the cluster to use round-robin load balancing.  The driver discovers all nodes in a cluster and cycles through them per request. All are considered 'local'. 

Return: undef


### cluster_set_load_balance_dc_aware

```perl
 my $int_CassError = $cass->cluster_set_load_balance_dc_aware($local_dc, $used_hosts_per_remote_dc, $allow_remote_dcs_for_local_cl);
```

Configures the cluster to use DC-aware load balancing. For each query, all live nodes in a primary 'local' DC are tried first, followed by any node from other DCs.  Note: This is the default, and does not need to be called unless switching an existing from another policy or changing settings. Without further configuration, a default local_dc is chosen from the first connected contact point, and no remote hosts are considered in query plans. If relying on this mechanism, be sure to use only contact points from the local DC. 

Return: CASS_OK if successful, otherwise an error occurred


### cluster_set_token_aware_routing

```perl
 $cass->cluster_set_token_aware_routing($enabled);
```

Configures the cluster to use Token-aware request routing, or not.  Default is cass_true (enabled).  This routing policy composes the base routing policy, routing requests first to replicas on nodes considered 'local' by the base load balancing policy. 

Return: undef


### cluster_set_tcp_nodelay

```perl
 $cass->cluster_set_tcp_nodelay($enable);
```

Enable/Disable Nagel's algorithm on connections.  Default: cass_false (disabled). 

Return: undef


### cluster_set_tcp_keepalive

```perl
 $cass->cluster_set_tcp_keepalive($enable, $delay_secs);
```

Enable/Disable TCP keep-alive  Default: cass_false (disabled). 

Return: undef


## Session

### session_new

```perl
 my $obj_CassSession = $cass->session_new();
```

Creates a new session. 

Return: obj_CassSession


### session_free

```perl
 $cass->session_free($session);
```

Frees a session instance. If the session is still connected it will be syncronously closed before being deallocated.  Important: Do not free a session in a future callback. Freeing a session in a future callback will cause a deadlock. 

Return: undef


### session_connect

```perl
 my $obj_CassFuture = $cass->session_connect($session);
```

Connects a session. 

Return: obj_CassFuture


### session_connect_keyspace

```perl
 my $obj_CassFuture = $cass->session_connect_keyspace($session, $keyspace);
```

Connects a session and sets the keyspace. 

Return: obj_CassFuture


### session_close

```perl
 my $obj_CassFuture = $cass->session_close($session);
```

Closes the session instance, outputs a close future which can be used to determine when the session has been terminated. This allows in-flight requests to finish. 

Return: obj_CassFuture


### session_prepare

```perl
 my $obj_CassFuture = $cass->session_prepare($session, $query);
```

Create a prepared statement. 

Return: obj_CassFuture


### session_execute

```perl
 my $obj_CassFuture = $cass->session_execute($session, $statement);
```

Execute a query or bound statement. 

Return: obj_CassFuture


### session_execute_batch

```perl
 my $obj_CassFuture = $cass->session_execute_batch($session, $batch);
```

Execute a batch statement. 

Return: obj_CassFuture


### session_get_schema

```perl
 my $obj_CassSchema = session_get_schema($session);
```

Gets a copy of this session's schema metadata. The returned copy of the schema metadata is not updated. This function must be called again to retrieve any schema changes since the previous call. 

Return: obj_CassSchema


## Schema metadata

### schema_free

```perl
 $cass->schema_free($schema);
```

Frees a schema instance. 

Return: undef


### schema_get_keyspace

```perl
 my $obj_CassSchemaMeta = $cass->schema_get_keyspace($schema, $keyspace_name);
```

Gets a the metadata for the provided keyspace name. 

Return: obj_CassSchemaMeta


### schema_meta_type

```perl
 my $int_CassSchemaMetaType = $cass->schema_meta_type($meta);
```

Gets the type of the specified schema metadata. 

Return: int_CassSchemaMetaType


### schema_meta_get_entry

```perl
 my $obj_CassSchemaMeta = $cass->schema_meta_get_entry($meta, $name);
```

Gets a metadata entry for the provided table/column name. 

Return: obj_CassSchemaMeta


### schema_meta_get_field

```perl
 my $obj_CassSchemaMetaField = $cass->schema_meta_get_field($meta, $name);
```

Gets a metadata field for the provided name. 

Return: obj_CassSchemaMetaField


### schema_meta_field_name

```perl
 my $res = $cass->schema_meta_field_name($field);
```

Gets the name for a schema metadata field 

Return: variable


### schema_meta_field_value

```perl
 my $obj_CassValue = $cass->schema_meta_field_value($field);
```

Gets the value for a schema metadata field 

Return: obj_CassValue


## SSL

### ssl_new

```perl
 my $obj_CassSsl = ssl_new($void);
```

Creates a new SSL context. 

Return: obj_CassSsl


### ssl_free

```perl
 $cass->ssl_free($ssl);
```

Frees a SSL context instance. 

Return: undef


### ssl_add_trusted_cert

```perl
 my $int_CassError = $cass->ssl_add_trusted_cert($ssl, $tcert_string);
```

Adds a trusted certificate. This is used to verify the peer's certificate. 

Return: CASS_OK if successful, otherwise an error occurred


### ssl_set_verify_flags

```perl
 $cass->ssl_set_verify_flags($ssl, $flags);
```

Sets verifcation performed on the peer's certificate.  CASS_SSL_VERIFY_NONE - No verification is performed CASS_SSL_VERIFY_PEER_CERT - Certificate is present and valid CASS_SSL_VERIFY_PEER_IDENTITY - IP address matches the certificate's common name or one of its subject alternative names. This implies the certificate is also present.  Default: CASS_SSL_VERIFY_PEER_CERT 

Return: undef


### ssl_set_cert

```perl
 my $int_CassError = $cass->ssl_set_cert($ssl, $cert);
```

Set client-side certificate chain. This is used to authenticate the client on the server-side. This should contain the entire Certificate chain starting with the certificate itself. 

Return: CASS_OK if successful, otherwise an error occurred


### ssl_set_private_key

```perl
 my $int_CassError = $cass->ssl_set_private_key($ssl, $key, $password);
```

Set client-side private key. This is used to authenticate the client on the server-side. 

Return: CASS_OK if successful, otherwise an error occurred


## Future

### future_free

```perl
 $cass->future_free($future);
```

Frees a future instance. A future can be freed anytime. 

Return: undef


### future_set_callback

```perl
 my $int_CassError = $cass->future_set_callback($future, $callback, $data);
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

Wait for the future to be set with either a result or error.  Important: Do not wait in a future callback. Waiting in a future callback will cause a deadlock. 

Return: variable


### future_wait_timed

```perl
 my $res = $cass->future_wait_timed($future, $timeout);
```

Wait for the future to be set or timeout. 

Return: variable


### future_get_result

```perl
 my $obj_CassResult = $cass->future_get_result($future);
```

Gets the result of a successful future. If the future is not ready this method will wait for the future to be set. The first successful call consumes the future, all subsequent calls will return NULL. 

Return: obj_CassResult


### future_get_prepared

```perl
 my $obj_CassPrepared = $cass->future_get_prepared($future);
```

Gets the result of a successful future. If the future is not ready this method will wait for the future to be set. The first successful call consumes the future, all subsequent calls will return NULL. 

Return: obj_CassPrepared


### future_error_code

```perl
 my $int_CassError = $cass->future_error_code($future);
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
 my $obj_CassStatement = $cass->statement_new($query, $parameter_count);
```

Creates a new query statement. 

Return: obj_CassStatement


### statement_free

```perl
 $cass->statement_free($statement);
```

Frees a statement instance. Statements can be immediately freed after being prepared, executed or added to a batch. 

Return: undef


### statement_add_key_index

```perl
 my $int_CassError = $cass->statement_add_key_index($statement, $index);
```

Adds a key index specifier to this a statement. When using token-aware routing, this can be used to tell the driver which parameters within a non-prepared, parameterized statement are part of the partition key.  Use consecutive calls for composite partition keys.  This is not necessary for prepared statements, as the key parameters are determined in the metadata processed in the prepare phase. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_set_keyspace

```perl
 my $int_CassError = $cass->statement_set_keyspace($statement, $keyspace);
```

Sets the statement's keyspace for use with token-aware routing.  This is not necessary for prepared statements, as the keyspace is determined in the metadata processed in the prepare phase. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_set_consistency

```perl
 my $int_CassError = $cass->statement_set_consistency($statement, $consistency);
```

Sets the statement's consistency level.  Default: CASS_CONSISTENCY_ONE 

Return: CASS_OK if successful, otherwise an error occurred


### statement_set_serial_consistency

```perl
 my $int_CassError = $cass->statement_set_serial_consistency($statement, $serial_consistency);
```

Sets the statement's serial consistency level.  Default: Not set 

Return: CASS_OK if successful, otherwise an error occurred


### statement_set_paging_size

```perl
 my $int_CassError = $cass->statement_set_paging_size($statement, $page_size);
```

Sets the statement's page size.  Default: -1 (Disabled) 

Return: CASS_OK if successful, otherwise an error occurred


### statement_set_paging_state

```perl
 my $int_CassError = $cass->statement_set_paging_state($statement, $result);
```

Sets the statement's paging state. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_null

```perl
 my $int_CassError = $cass->statement_bind_null($statement, $index);
```

Binds null to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_int32

```perl
 my $int_CassError = $cass->statement_bind_int32($statement, $index, $value);
```

Binds an "int" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_int64

```perl
 my $int_CassError = $cass->statement_bind_int64($statement, $index, $value);
```

Binds a "bigint", "counter" or "timestamp" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_float

```perl
 my $int_CassError = $cass->statement_bind_float($statement, $index, $value);
```

Binds a "float" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_double

```perl
 my $int_CassError = $cass->statement_bind_double($statement, $index, $value);
```

Binds a "double" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_bool

```perl
 my $int_CassError = $cass->statement_bind_bool($statement, $index, $value);
```

Binds a "boolean" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_string

```perl
 my $int_CassError = $cass->statement_bind_string($statement, $index, $value);
```

Binds a "ascii", "text" or "varchar" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_bytes

```perl
 my $int_CassError = $cass->statement_bind_bytes($statement, $index, $value);
```

Binds a "blob" or "varint" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_uuid

```perl
 my $int_CassError = $cass->statement_bind_uuid($statement, $index, $value);
```

Binds a "uuid" or "timeuuid" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_inet

```perl
 my $int_CassError = $cass->statement_bind_inet($statement, $index, $value);
```

Binds an "inet" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_decimal

```perl
 my $int_CassError = $cass->statement_bind_decimal($statement, $index, $myhash);
```

Bind a "decimal" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_custom

```perl
 my $int_CassError = $cass->statement_bind_custom($statement, $index, $data);
```

Binds any type to a query or bound statement at the specified index. A value can be copied into the resulting output buffer. This is normally reserved for large values to avoid extra memory copies. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_collection

```perl
 my $int_CassError = $cass->statement_bind_collection($statement, $index, $collection);
```

Bind a "list", "map", or "set" to a query or bound statement at the specified index. 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_int32_by_name

```perl
 my $int_CassError = $cass->statement_bind_int32_by_name($statement, $name, $value);
```

Binds an "int" to all the values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_int64_by_name

```perl
 my $int_CassError = $cass->statement_bind_int64_by_name($statement, $name, $value);
```

Binds a "bigint", "counter" or "timestamp" to all values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_float_by_name

```perl
 my $int_CassError = $cass->statement_bind_float_by_name($statement, $name, $value);
```

Binds a "float" to all the values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_double_by_name

```perl
 my $int_CassError = $cass->statement_bind_double_by_name($statement, $name, $value);
```

Binds a "double" to all the values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_bool_by_name

```perl
 my $int_CassError = $cass->statement_bind_bool_by_name($statement, $name, $value);
```

Binds a "boolean" to all the values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_string_by_name

```perl
 my $int_CassError = $cass->statement_bind_string_by_name($statement, $name, $value);
```

Binds a "ascii", "text" or "varchar" to all the values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_bytes_by_name

```perl
 my $int_CassError = $cass->statement_bind_bytes_by_name($statement, $name, $value);
```

Binds a "blob" or "varint" to all the values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_uuid_by_name

```perl
 my $int_CassError = $cass->statement_bind_uuid_by_name($statement, $name, $value);
```

Binds a "uuid" or "timeuuid" to all the values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_inet_by_name

```perl
 my $int_CassError = $cass->statement_bind_inet_by_name($statement, $name, $value);
```

Binds an "inet" to all the values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_decimal_by_name

```perl
 my $int_CassError = $cass->statement_bind_decimal_by_name($statement, $name, $myhash);
```

Binds a "decimal" to all the values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_custom_by_name

```perl
 my $int_CassError = $cass->statement_bind_custom_by_name($statement, $name, $data);
```

Binds any type to all the values with the specified name. A value can be copied into the resulting output buffer. This is normally reserved for large values to avoid extra memory copies.  This can only be used with statements created by $cass->prepared_bind(). 

Return: CASS_OK if successful, otherwise an error occurred


### statement_bind_collection_by_name

```perl
 my $int_CassError = $cass->statement_bind_collection_by_name($statement, $name, $collection);
```

Bind a "list", "map", or "set" to all the values with the specified name.  This can only be used with statements created by $cass->prepared_bind(). 

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
 my $obj_CassStatement = $cass->prepared_bind($prepared);
```

Creates a bound statement from a pre-prepared statement. 

Return: obj_CassStatement


## Batch

### batch_new

```perl
 my $obj_CassBatch = $cass->batch_new($type);
```

Creates a new batch statement with batch type. 

Return: obj_CassBatch


### batch_free

```perl
 $cass->batch_free($batch);
```

Frees a batch instance. Batches can be immediately freed after being executed. 

Return: undef


### batch_set_consistency

```perl
 my $int_CassError = $cass->batch_set_consistency($batch, $consistency);
```

Sets the batch's consistency level 

Return: CASS_OK if successful, otherwise an error occurred


### batch_add_statement

```perl
 my $int_CassError = $cass->batch_add_statement($batch, $statement);
```

Adds a statement to a batch. 

Return: CASS_OK if successful, otherwise an error occurred


## Collection

### collection_new

```perl
 my $obj_CassCollection = $cass->collection_new($type, $item_count);
```

Creates a new collection. 

Return: obj_CassCollection


### collection_free

```perl
 $cass->collection_free($collection);
```

Frees a collection instance. 

Return: undef


### collection_append_int32

```perl
 my $int_CassError = $cass->collection_append_int32($collection, $value);
```

Appends an "int" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_int64

```perl
 my $int_CassError = $cass->collection_append_int64($collection, $value);
```

Appends a "bigint", "counter" or "timestamp" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_float

```perl
 my $int_CassError = $cass->collection_append_float($collection, $value);
```

Appends a "float" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_double

```perl
 my $int_CassError = $cass->collection_append_double($collection, $value);
```

Appends a "double" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_bool

```perl
 my $int_CassError = $cass->collection_append_bool($collection, $value);
```

Appends a "boolean" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_string

```perl
 my $int_CassError = $cass->collection_append_string($collection, $value);
```

Appends a "ascii", "text" or "varchar" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_bytes

```perl
 my $int_CassError = $cass->collection_append_bytes($collection, $value);
```

Appends a "blob" or "varint" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_uuid

```perl
 my $int_CassError = $cass->collection_append_uuid($collection, $value);
```

Appends a "uuid" or "timeuuid"  to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_inet

```perl
 my $int_CassError = $cass->collection_append_inet($collection, $value);
```

Appends an "inet" to the collection. 

Return: CASS_OK if successful, otherwise an error occurred


### collection_append_decimal

```perl
 my $int_CassError = $cass->collection_append_decimal($collection, $myhash);
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
 my $obj_CassRow = $cass->result_first_row($result);
```

Gets the first row of the result. 

Return: obj_CassRow


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


### iterator_type

```perl
 my $CassIteratorType = $cass->iterator_type($iterator);
```

Gets the type of the specified iterator. 

Return: CassIteratorType


### iterator_from_result

```perl
 my $obj_CassIterator = $cass->iterator_from_result($result);
```

Creates a new iterator for the specified result. This can be used to iterate over rows in the result. 

Return: obj_CassIterator


### iterator_from_row

```perl
 my $obj_CassIterator = $cass->iterator_from_row($row);
```

Creates a new iterator for the specified row. This can be used to iterate over columns in a row. 

Return: obj_CassIterator


### iterator_from_collection

```perl
 my $obj_CassIterator = $cass->iterator_from_collection($value);
```

Creates a new iterator for the specified collection. This can be used to iterate over values in a collection. 

Return: obj_CassIterator


### iterator_from_map

```perl
 my $obj_CassIterator = $cass->iterator_from_map($value);
```

Creates a new iterator for the specified map. This can be used to iterate over key/value pairs in a map. 

Return: obj_CassIterator


### iterator_from_schema

```perl
 my $obj_CassIterator = $cass->iterator_from_schema($schema);
```

Creates a new iterator for the specified schema. This can be used to iterate over keyspace entries. 

Return: obj_CassIterator


### iterator_from_schema_meta

```perl
 my $obj_CassIterator = $cass->iterator_from_schema_meta($meta);
```

Creates a new iterator for the specified schema metadata. This can be used to iterate over table/column entries. 

Return: obj_CassIterator


### iterator_fields_from_schema_meta

```perl
 my $obj_CassIterator = $cass->iterator_fields_from_schema_meta($meta);
```

Creates a new iterator for the specified schema metadata. This can be used to iterate over schema metadata fields. 

Return: obj_CassIterator


### iterator_next

```perl
 my $res = $cass->iterator_next($iterator);
```

Advance the iterator to the next row, column, or collection item. 

Return: variable


### iterator_get_row

```perl
 my $obj_CassRow = $cass->iterator_get_row($iterator);
```

Gets the row at the result iterator's current position.  Calling $cass->iterator_next() will invalidate the previous row returned by this method. 

Return: obj_CassRow


### iterator_get_column

```perl
 my $obj_CassValue = $cass->iterator_get_column($iterator);
```

Gets the column value at the row iterator's current position.  Calling $cass->iterator_next() will invalidate the previous column returned by this method. 

Return: obj_CassValue


### iterator_get_value

```perl
 my $obj_CassValue = $cass->iterator_get_value($iterator);
```

Gets the value at the collection iterator's current position.  Calling $cass->iterator_next() will invalidate the previous value returned by this method. 

Return: obj_CassValue


### iterator_get_map_key

```perl
 my $obj_CassValue = $cass->iterator_get_map_key($iterator);
```

Gets the key at the map iterator's current position.  Calling $cass->iterator_next() will invalidate the previous value returned by this method. 

Return: obj_CassValue


### iterator_get_map_value

```perl
 my $obj_CassValue = $cass->iterator_get_map_value($iterator);
```

Gets the value at the map iterator's current position.  Calling $cass->iterator_next() will invalidate the previous value returned by this method. 

Return: obj_CassValue


### iterator_get_schema_meta

```perl
 my $obj_CassSchemaMeta = $cass->iterator_get_schema_meta($iterator);
```

Gets the schema metadata entry at the iterator's current position.  Calling $cass->iterator_next() will invalidate the previous value returned by this method. 

Return: obj_CassSchemaMeta


### iterator_get_schema_meta_field

```perl
 my $obj_CassSchemaMetaField = $cass->iterator_get_schema_meta_field($iterator);
```

Gets the schema metadata field at the iterator's current position.  Calling $cass->iterator_next() will invalidate the previous value returned by this method. 

Return: obj_CassSchemaMetaField


## Row

### row_get_column

```perl
 my $obj_CassValue = $cass->row_get_column($row, $index);
```

Get the column value at index for the specified row. 

Return: obj_CassValue


### row_get_column_by_name

```perl
 my $obj_CassValue = $cass->row_get_column_by_name($row, $name);
```

Get the column value by name for the specified row. 

Return: obj_CassValue


## Value

### value_get_int32

```perl
 my $int_CassError = $cass->value_get_int32($value, $output);
```

Gets an int32 for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_int64

```perl
 my $int_CassError = $cass->value_get_int64($value, $output);
```

Gets an int64 for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_float

```perl
 my $int_CassError = $cass->value_get_float($value, $output);
```

Gets a float for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_double

```perl
 my $int_CassError = $cass->value_get_double($value, $output);
```

Gets a double for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_bool

```perl
 my $int_CassError = $cass->value_get_bool($value, $output);
```

Gets a bool for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_uuid

```perl
 my $int_CassError = $cass->value_get_uuid($value, $output);
```

Gets a UUID for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_inet

```perl
 my $int_CassError = $cass->value_get_inet($value, $output);
```

Gets an INET for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_string

```perl
 my $int_CassError = $cass->value_get_string($value, $output);
```

Gets a string for the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_bytes

```perl
 my $int_CassError = $cass->value_get_bytes($value, $output);
```

Gets the bytes of the specified value. 

Return: CASS_OK if successful, otherwise an error occurred


### value_get_decimal

```perl
 my $int_CassError = $cass->value_get_decimal($value, $output);
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


### value_is_collection

```perl
 my $res = $cass->value_is_collection($value);
```

Returns true if a specified value is a collection. 

Return: variable


### value_item_count

```perl
 my $res = $cass->value_item_count($value);
```

Get the number of items in a collection. Works for all collection types. 

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

### uuid_gen_new

```perl
 my $CassUuidGen = uuid_gen_new($void);
```

Creates a new UUID generator.  Note: This object is thread-safe. It is best practice to create and reuse a single object per application.  Note: If unique node information (IP address) is unable to be determined then random node information will be generated. 

Return: CassUuidGen


### uuid_gen_new_with_node

```perl
 my $CassUuidGen = uuid_gen_new_with_node($node);
```

Creates a new UUID generator with custom node information.  Note: This object is thread-safe. It is best practice to create and reuse a single object per application. 

Return: CassUuidGen


### uuid_gen_free

```perl
 uuid_gen_free($uuid_gen);
```

Frees a UUID generator instance. 

Return: undef


### uuid_gen_time

```perl
 uuid_gen_time($uuid_gen, $output);
```

Generates a V1 (time) UUID.  Note: This method is thread-safe 

Return: undef


### uuid_gen_random

```perl
 uuid_gen_random($uuid_gen, $output);
```

Generates a new V4 (random) UUID  Note: This method is thread-safe 

Return: undef


### uuid_gen_from_time

```perl
 uuid_gen_from_time($uuid_gen, $timestamp, $output);
```

Generates a V1 (time) UUID for the specified time.  Note: This method is thread-safe 

Return: undef


### uuid_min_from_time

```perl
 uuid_min_from_time($timestamp, $output);
```

Sets the UUID to the minimum V1 (time) value for the specified time. 

Return: undef


### uuid_max_from_time

```perl
 $cass->uuid_max_from_time($time, $output);
```

Sets the UUID to the maximum V1 (time) value for the specified time. 

Return: undef


### uuid_timestamp

```perl
 my $res = uuid_timestamp($uuid);
```

Gets the timestamp for a V1 UUID 

Return: variable


### uuid_version

```perl
 my $res = uuid_version($uuid);
```

Gets the version for a UUID 

Return: variable


### uuid_string

```perl
 uuid_string($uuid, $output);
```

Returns a null-terminated string for the specified UUID. 

Return: undef


### uuid_from_string

```perl
 my $int_CassError = uuid_from_string($uuid_str, $output);
```

Returns a UUID for the specified string.  Example: "550e8400-e29b-41d4-a716-446655440000" 

Return: CASS_OK if successful, otherwise an error occurred


## Error

### error_desc

```perl
 my $res = $cass->error_desc($error_code);
```

Gets a description for an error code. 

Return: variable


## Log

### log_set_level

```perl
 log_set_level($level);
```

Sets the log level.  Note: This needs to be done before any call that might log, such as any of the $cass->cluster_*() or $cass->ssl_*() functions.  Default: CASS_LOG_WARN 

Return: undef


### log_set_callback

```perl
 $cass->log_set_callback($callback, $data);
```

Sets a callback for handling logging events.  Note: This needs to be done before any call that might log, such as any of the $cass->cluster_*() or $cass->ssl_*() functions.  Default: An internal callback that prints to stderr 

Return: undef


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

This software is copyright (c) 2015 by Alexander Borisov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

See libcassandra license and COPYRIGHT https://github.com/datastax/cpp-driver
