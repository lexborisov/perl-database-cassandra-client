//
//
//  Created by Alexander Borisov on 22.07.14.
//  Copyright (c) 2014 Alexander Borisov. All rights reserved.
//

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <pthread.h>
#include <cassandra.h>

static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

typedef struct
{
	CassCluster *cluster;
	void *callback_future;
	void *callback_future_arg;
	void *callback_log;
	void *callback_log_arg;
	
	PerlInterpreter *perl_int;
	
	// for simple api
	CassSession *session;
}
cassandra_t;

typedef cassandra_t * Database__Cassandra__Client;

static inline void base_callback_future(CassFuture* future, void *arg)
{
	cassandra_t *cass = (cassandra_t *)arg;
	
	pthread_mutex_lock(&mutex);
	
	dTHXa(cass->perl_int);
	PERL_SET_CONTEXT( cass->perl_int );
	{
		dSP;
		
		ENTER;
		SAVETMPS;
		
		SV *future_prl = sv_newmortal();
		sv_setref_pv(future_prl, "CassFuturePtr", (void*)future);
		
		PUSHMARK(sp);
			XPUSHs(SvRV(future_prl));
			
			if(cass->callback_future_arg)
			{
				XPUSHs(cass->callback_future_arg);
			}
		PUTBACK;
		
		call_sv((SV *)cass->callback_future, G_SCALAR);
		
		FREETMPS;
		LEAVE;
	}
	
	pthread_mutex_unlock(&mutex);
}

static inline void base_callback_log(cass_uint64_t time, CassLogLevel severity, CassString message, void *arg)
{
	cassandra_t *cass = (cassandra_t *)arg;
	
	pthread_mutex_lock(&mutex);
	
	dTHXa(cass->perl_int);
	PERL_SET_CONTEXT( cass->perl_int );
	{
		dSP;
		
		ENTER;
		SAVETMPS;
		
		PUSHMARK(sp);
			XPUSHs( sv_2mortal( newSViv(time) ) );
			XPUSHs( sv_2mortal( newSViv(severity) ) );
			XPUSHs( sv_2mortal( newSVpv(message.data, message.length) ) );
			
			if(cass->callback_log_arg)
			{
				XPUSHs(cass->callback_log_arg);
			}
		PUTBACK;
		
		call_sv((SV *)cass->callback_log, G_DISCARD);
		
		FREETMPS;
		LEAVE;
	}
	
	pthread_mutex_unlock(&mutex);
}

SV * get_sv_by_int32(const CassValue *column)
{
	cass_int32_t s_output;
	if(cass_value_get_int32(column, &s_output) == CASS_OK)
	{
		return newSViv(s_output);
	}
	
	return &PL_sv_undef;
}

SV * get_sv_by_int64(const CassValue *column)
{
	cass_int64_t s_output;
	if(cass_value_get_int64(column, &s_output) == CASS_OK)
	{
		return newSViv(s_output);
	}
	
	return &PL_sv_undef;
}

SV * get_sv_by_float(const CassValue *column)
{
	cass_float_t s_output;
	if(cass_value_get_float(column, &s_output) == CASS_OK)
	{
		return newSVnv(s_output);
	}
	
	return &PL_sv_undef;
}

SV * get_sv_by_double(const CassValue *column)
{
	cass_double_t s_output;
	if(cass_value_get_double(column, &s_output) == CASS_OK)
	{
		return newSVnv(s_output);
	}
	
	return &PL_sv_undef;
}

SV * get_sv_by_bool(const CassValue *column)
{
	cass_bool_t s_output;
	if(cass_value_get_bool(column, &s_output) == CASS_OK)
	{
		return newSViv(s_output);
	}
	
	return &PL_sv_undef;
}

SV * get_sv_by_uuid(const CassValue *column)
{
	CassUuid s_output;
	if(cass_value_get_uuid(column, s_output) == CASS_OK)
	{
		return newSVpv((char *)(s_output), CASS_UUID_STRING_LENGTH);
	}
	
	return &PL_sv_undef;
}

SV * get_sv_by_inet(const CassValue *column)
{
	CassInet s_output;
	if(cass_value_get_inet(column, &s_output) == CASS_OK)
	{
		return newSVpv((char *)(s_output.address), s_output.address_length);
	}
	
	return &PL_sv_undef;
}

SV * get_sv_by_string(const CassValue *column)
{
	CassString s_output;
	if(cass_value_get_string(column, &s_output) == CASS_OK)
	{
		return newSVpv(s_output.data, s_output.length);
	}
	
	return &PL_sv_undef;
}

SV * get_sv_by_bytes(const CassValue *column)
{
	CassBytes s_output;
	if(cass_value_get_bytes(column, &s_output) == CASS_OK)
	{
		return newSVpv((char *)s_output.data, s_output.size);
	}
	
	return &PL_sv_undef;
}

SV * get_sv_by_decimal(const CassValue *column)
{
	CassDecimal s_output;
	if(cass_value_get_decimal(column, &s_output) == CASS_OK)
	{
		SV **ha;
		HV *hash_value = newHV();
		ha = hv_store(hash_value, "scale", 5, newSViv(s_output.scale), 0);
		ha = hv_store(hash_value, "bytes", 5, newSVpv((char *)(s_output.varint.data), s_output.varint.size), 0);
		
		return newRV_noinc( (SV *)hash_value );
	}
	
	return &PL_sv_undef;
}

typedef SV * (*sv_by_type_cass_func)(const CassValue *column);

// not safe
void *sv_by_type_cass[CASS_VALUE_TYPE_SET] = {
	get_sv_by_bytes,
	get_sv_by_string,
	get_sv_by_int64,
	get_sv_by_bytes,
	get_sv_by_bool,
	get_sv_by_int32,
	get_sv_by_decimal,
	get_sv_by_double,
	get_sv_by_float,
	get_sv_by_int32,
	get_sv_by_string,
	get_sv_by_int64,
	get_sv_by_uuid,
	get_sv_by_string,
	get_sv_by_int32,
	get_sv_by_uuid,
	get_sv_by_inet,
	0
};

//		if(SvROK(sv_bind) && SvTYPE(SvRV(sv_bind)) == SVt_PVAV)
//		{
//			AV* array = (AV*)SvRV(sv_bind);
//			SSize_t elem_size = av_len(array) + 1;
//            SSize_t i;
//			
//			for (i = 0; i < elem_size; i++)
//			{
//				SV **sv_value = av_fetch(array, i, 0);
//				unsigned char *key = (unsigned char *)SvPV(*sv_value, len);
//				
//				unsigned char *output = NULL;
//				
//				cass_statement_bind_custom(statement, i, (cass_size_t)len, &output);
//				
//				size_t size_m = sizeof(int32_t) + sizeof(int32_t);
//				
//				size_t i;
//				for(i = 0; i < len; i++)
//				{
//					output[i] = key[i];
//				}
//			}
//		}

MODULE = Database::Cassandra::Client  PACKAGE = Database::Cassandra::Client

PROTOTYPES: DISABLE

####
#
# Simple api
#
####

CassError
sm_connect(cass, contact_points)
	Database::Cassandra::Client cass;
	char *contact_points;
	
	CODE:
		cass_cluster_set_contact_points(cass->cluster, contact_points);
		
		CassError rc = CASS_OK;
		CassFuture* future = cass_cluster_connect(cass->cluster);
		
		cass_future_wait(future);
		rc = cass_future_error_code(future);
		
		if(rc == CASS_OK)
			cass->session = cass_future_get_session(future);
		
		cass_future_free(future);
		
		RETVAL = rc;
	OUTPUT:
		RETVAL

CassStatement*
sm_prepare(cass, query, out_status)
	Database::Cassandra::Client cass;
	SV *query;
	SV *out_status;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		sv_setiv(out_status, CASS_OK);
		
		char *c_query = SvPV( query, len );
		CassString cass_query = cass_string_init(c_query);
		
		CassFuture *future = cass_session_prepare(cass->session, cass_query);
		cass_future_wait(future);
		
		CassStatement *statement = NULL;
		CassPrepared *prepared = NULL;
		CassError rc = cass_future_error_code(future);
		
		if(rc == CASS_OK)
		{
			prepared = (CassPrepared *)cass_future_get_prepared(future);
			statement = cass_prepared_bind(prepared);
			cass_prepared_free(prepared);
		}
		else
		{
			sv_setiv(out_status, rc);
		}
		cass_future_free(future);
		
		RETVAL = statement;
		
	OUTPUT:
		RETVAL

CassError
sm_execute_query(cass, statement)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	
	CODE:
		CassError rc = CASS_OK;
		
		if(statement)
		{
			CassFuture *future = cass_session_execute(cass->session, statement);
			cass_future_wait(future);
			
			rc = cass_future_error_code(future);
			
			cass_future_free(future);
			cass_statement_free(statement);
		}
		else
			rc = CASS_ERROR_LIB_NULL_VALUE;
		
		RETVAL = rc;
	OUTPUT:
		RETVAL

SV*
sm_select_query(cass, statement, binds, out_status)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *binds;
	SV *out_status;
	
	CODE:
		CassError rc = CASS_OK;
		sv_setiv(out_status, rc);
		
		AV* array = newAV();
		
		if(statement)
		{
			CassFuture *future = cass_session_execute(cass->session, statement);
			cass_future_wait(future);
			
			if((rc = cass_future_error_code(future)) == CASS_OK)
			{
				const CassRow *row = NULL;
				const CassResult *result = cass_future_get_result(future);
				CassIterator *iterator   = cass_iterator_from_result(result);
				
				cass_size_t column_id;
				cass_size_t column_count = cass_result_column_count(result);
				
				SV **ha;
				
				while(cass_iterator_next(iterator))
				{
					row = cass_iterator_get_row(iterator);
					
					HV *hash = newHV();
					
					for(column_id = 0; column_id < column_count; column_id++)
					{
						const CassValue *column = cass_row_get_column(row, column_id);
						CassString column_name  = cass_result_column_name(result, column_id);
						
						if(cass_value_is_null(column))
						{
							ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
							continue;
						}
						
						switch (cass_result_column_type(result, column_id))
						{
							case CASS_VALUE_TYPE_UNKNOWN:
							{
								ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								break;
							}
							case CASS_VALUE_TYPE_CUSTOM:
							{
								CassBytes s_output;
								if(cass_value_get_bytes(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSVpv((char *)(s_output.data), s_output.size), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_ASCII:
							{
								CassString s_output;
								if(cass_value_get_string(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSVpv(s_output.data, s_output.length), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_BIGINT:
							{
								cass_int64_t s_output;
								if(cass_value_get_int64(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSViv(s_output), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_BLOB:
							{
								CassBytes s_output;
								if(cass_value_get_bytes(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSVpv((char *)(s_output.data), s_output.size), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_BOOLEAN:
							{
								cass_bool_t s_output;
								if(cass_value_get_bool(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSViv(s_output), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_COUNTER:
							{
								cass_int32_t s_output;
								if(cass_value_get_int32(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSViv(s_output), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_DECIMAL:
							{
								CassDecimal s_output;
								if(cass_value_get_decimal(column, &s_output)  == CASS_OK)
								{
									HV *hash_value = newHV();
									ha = hv_store(hash_value, "scale", 5, newSViv(s_output.scale), 0);
									ha = hv_store(hash_value, "bytes", 5, newSVpv((char *)(s_output.varint.data), s_output.varint.size), 0);
									ha = hv_store(hash, column_name.data, column_name.length, newRV_noinc( (SV *)hash_value ), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_DOUBLE:
							{
								cass_double_t s_output;
								if(cass_value_get_double(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSVnv(s_output), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_FLOAT:
							{
								cass_float_t s_output;
								if(cass_value_get_float(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSVnv(s_output), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_INT:
							{
								cass_int32_t s_output;
								if(cass_value_get_int32(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSViv(s_output), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_TEXT:
							{
								CassString s_output;
								if(cass_value_get_string(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSVpv(s_output.data, s_output.length), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_TIMESTAMP:
							{
								cass_int64_t s_output;
								if(cass_value_get_int64(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSViv(s_output), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_UUID:
							{
								CassUuid s_output;
								if(cass_value_get_uuid(column, s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSVpv((char *)(s_output), CASS_UUID_STRING_LENGTH), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_VARCHAR:
							{
								CassString s_output;
								if(cass_value_get_string(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSVpv(s_output.data, s_output.length), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_VARINT:
							{
								cass_int32_t s_output;
								if(cass_value_get_int32(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSViv(s_output), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_TIMEUUID:
							{
								CassUuid s_output;
								if(cass_value_get_uuid(column, s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSVpv((char *)(s_output), CASS_UUID_STRING_LENGTH), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_INET:
							{
								CassInet s_output;
								if(cass_value_get_inet(column, &s_output) == CASS_OK)
								{
									ha = hv_store(hash, column_name.data, column_name.length, newSVpv((char *)(s_output.address), s_output.address_length), 0);
								}
								else
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								}
								
								break;
							}
							case CASS_VALUE_TYPE_LIST:
							{
								CassIterator *iterator_l = cass_iterator_from_collection(column);
								CassValueType type_key = cass_value_primary_sub_type(column);
								
								if(type_key > CASS_VALUE_TYPE_INET)
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
									break;
								}
								
								AV* array_list = newAV();
								
								while (cass_iterator_next(iterator_l))
								{
									SV *sv_key = (*((sv_by_type_cass_func)sv_by_type_cass[type_key]))
										(cass_iterator_get_value(iterator_l));
									
									av_push(array_list, sv_key); 
								}
								cass_iterator_free(iterator_l);
								
								ha = hv_store(hash, column_name.data, column_name.length, newRV_noinc((SV *)array_list), 0);
								break;
							}
							case CASS_VALUE_TYPE_MAP:
							{
								CassIterator* iterator_l = cass_iterator_from_map(column);
								
								CassValueType type_key = cass_value_primary_sub_type(column);
								CassValueType type_value = cass_value_secondary_sub_type(column);
								
								if(type_key > CASS_VALUE_TYPE_INET || type_value > CASS_VALUE_TYPE_INET)
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
									break;
								}
								
								HV *hash_value = newHV();
								STRLEN len;
								
								while (cass_iterator_next(iterator_l))
								{
									SV *sv_key = (*((sv_by_type_cass_func)sv_by_type_cass[type_key]))
										(cass_iterator_get_map_key(iterator_l));
									
									SV *sv_value = (*((sv_by_type_cass_func)sv_by_type_cass[type_value]))
										(cass_iterator_get_map_value(iterator_l));
									
									char *key_c = SvPV( sv_key, len );
									
									ha = hv_store(hash_value, key_c, len, sv_value, 0);
								}
								cass_iterator_free(iterator_l);
								
								ha = hv_store(hash, column_name.data, column_name.length, newRV_noinc((SV *)hash_value), 0);
								break;
							}
							case CASS_VALUE_TYPE_SET:
							{
								CassIterator *iterator_l = cass_iterator_from_collection(column);
								CassValueType type_key = cass_value_primary_sub_type(column);
								
								if(type_key > CASS_VALUE_TYPE_INET)
								{
									ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
									break;
								}
								
								AV* array_list = newAV();
								
								while (cass_iterator_next(iterator_l))
								{
									SV *sv_key = (*((sv_by_type_cass_func)sv_by_type_cass[type_key]))
										(cass_iterator_get_value(iterator_l));
									
									av_push(array_list, sv_key); 
								}
								cass_iterator_free(iterator_l);
								
								ha = hv_store(hash, column_name.data, column_name.length, newRV_noinc((SV *)array_list), 0);
								break;
							}
							default:
								ha = hv_store(hash, column_name.data, column_name.length, &PL_sv_undef, 0);
								break;
						}
					}
					
					av_push(array, newRV_noinc((SV*)hash));
				}
				
				cass_result_free(result);
				cass_iterator_free(iterator);
			}
			
			cass_future_free(future);
			cass_statement_free(statement);
		}
		else
			sv_setiv(out_status, CASS_ERROR_LIB_NULL_VALUE);
		
		RETVAL = newRV_noinc((SV *)array);
	OUTPUT:
		RETVAL

void
sm_destroy(cass)
	Database::Cassandra::Client cass;
	
	CODE:
		if(cass->session)
		{
			CassFuture *close_future = cass_session_close(cass->session);
			cass_future_wait(close_future);
			cass_future_free(close_future);
			
			cass->session = NULL;
		}
		
		if(cass->cluster)
			cass_cluster_free(cass->cluster);
		
		cass->cluster = NULL;

####
#
# Base api
#
####

Database::Cassandra::Client
cluster_new(name = 0)
	char *name;
	
	CODE:
		cassandra_t *cass = malloc(sizeof(cassandra_t));
		
		cass->cluster = cass_cluster_new();
		cass->callback_future     = NULL;
		cass->callback_future_arg = NULL;
		cass->callback_log        = NULL;
		cass->callback_log_arg    = NULL;
		cass->perl_int            = NULL;
		cass->session             = NULL;
		
		RETVAL = cass;
	OUTPUT:
		RETVAL

CassError
cluster_set_contact_points(cass, contact_points = 0)
	Database::Cassandra::Client cass;
	const char *contact_points;
	
	CODE:
		RETVAL = cass_cluster_set_contact_points(cass->cluster, contact_points);
	OUTPUT:
		RETVAL

CassError
cluster_set_port(cass, port)
	Database::Cassandra::Client cass;
	int port;
	
	CODE:
		RETVAL = cass_cluster_set_port(cass->cluster, port);
	OUTPUT:
		RETVAL

CassError
cluster_set_protocol_version(cass, protocol_version)
	Database::Cassandra::Client cass;
	int protocol_version;
	
	CODE:
		RETVAL = cass_cluster_set_protocol_version(cass->cluster, protocol_version);
	OUTPUT:
		RETVAL

CassError
cluster_set_num_threads_io(cass, num_threads)
	Database::Cassandra::Client cass;
	unsigned num_threads;
	
	CODE:
		RETVAL = cass_cluster_set_num_threads_io(cass->cluster, num_threads);
	OUTPUT:
		RETVAL

CassError
cluster_set_queue_size_io(cass, queue_size)
	Database::Cassandra::Client cass;
	unsigned queue_size;
	
	CODE:
		RETVAL = cass_cluster_set_queue_size_io(cass->cluster, queue_size);
	OUTPUT:
		RETVAL

CassError
cluster_set_core_connections_per_host(cass, num_connections)
	Database::Cassandra::Client cass;
	unsigned num_connections;
	
	CODE:
		RETVAL = cass_cluster_set_core_connections_per_host(cass->cluster, num_connections);
	OUTPUT:
		RETVAL

CassError
cluster_set_max_connections_per_host(cass, num_connections)
	Database::Cassandra::Client cass;
	unsigned num_connections;
	
	CODE:
		RETVAL = cass_cluster_set_max_connections_per_host(cass->cluster, num_connections);
	OUTPUT:
		RETVAL

CassError
cluster_set_max_concurrent_creation(cass, num_connections)
	Database::Cassandra::Client cass;
	unsigned num_connections;
	
	CODE:
		RETVAL = cass_cluster_set_max_concurrent_creation(cass->cluster, num_connections);
	OUTPUT:
		RETVAL

CassError
cluster_set_pending_requests_high_water_mark(cass, num_requests)
	Database::Cassandra::Client cass;
	unsigned num_requests;
	
	CODE:
		RETVAL = cass_cluster_set_pending_requests_high_water_mark(cass->cluster, num_requests);
	OUTPUT:
		RETVAL

CassError
cluster_set_pending_requests_low_water_mark(cass, num_requests)
	Database::Cassandra::Client cass;
	unsigned num_requests;
	
	CODE:
		RETVAL = cass_cluster_set_pending_requests_low_water_mark(cass->cluster, num_requests);
	OUTPUT:
		RETVAL

CassError
cluster_set_max_concurrent_requests_threshold(cass, num_requests)
	Database::Cassandra::Client cass;
	unsigned num_requests;
	
	CODE:
		RETVAL = cass_cluster_set_max_concurrent_requests_threshold(cass->cluster, num_requests);
	OUTPUT:
		RETVAL

CassError
cluster_set_connect_timeout(cass, timeout)
	Database::Cassandra::Client cass;
	unsigned timeout;
	
	CODE:
		RETVAL = cass_cluster_set_connect_timeout(cass->cluster, timeout);
	OUTPUT:
		RETVAL

CassError
cluster_set_request_timeout(cass, timeout)
	Database::Cassandra::Client cass;
	unsigned timeout;
	
	CODE:
		RETVAL = cass_cluster_set_request_timeout(cass->cluster, timeout);
	OUTPUT:
		RETVAL

CassError
cluster_set_log_level(cass, level)
	Database::Cassandra::Client cass;
	int level;
	
	CODE:
		RETVAL = cass_cluster_set_log_level(cass->cluster, (CassLogLevel)level);
	OUTPUT:
		RETVAL

CassError
cluster_set_log_callback(cass, callback, data)
	Database::Cassandra::Client cass;
	SV *callback;
	SV *data;
	
	CODE:
		SV *sub = newSVsv(callback);
		
		if(cass->callback_log)
		{
			sv_2mortal((SV *)cass->callback_log);
		}
		
		cass->callback_log     = (void *)sub;
		cass->callback_log_arg = (void *)data;
		
		if(cass->perl_int == NULL)
			cass->perl_int = Perl_get_context();
		
		RETVAL = cass_cluster_set_log_callback(cass->cluster, base_callback_log, (void *)cass);
	OUTPUT:
		RETVAL

CassError
cluster_set_credentials(cass, username, password)
	Database::Cassandra::Client cass;
	const char* username;
	const char* password;
	
	CODE:
		RETVAL = cass_cluster_set_credentials(cass->cluster, username, password);
	OUTPUT:
		RETVAL

CassError
cluster_set_load_balance_round_robin(cass)
	Database::Cassandra::Client cass;
	
	CODE:
		RETVAL = cass_cluster_set_load_balance_round_robin(cass->cluster);
	OUTPUT:
		RETVAL

CassError
cluster_set_load_balance_dc_aware(cass, local_dc)
	Database::Cassandra::Client cass;
	const char* local_dc;
	
	CODE:
		RETVAL = cass_cluster_set_load_balance_dc_aware(cass->cluster, local_dc);
	OUTPUT:
		RETVAL

CassFuture*
cluster_connect(cass)
	Database::Cassandra::Client cass;
	
	CODE:
		RETVAL = cass_cluster_connect(cass->cluster);
	OUTPUT:
		RETVAL

CassFuture*
cluster_connect_keyspace(cass, keyspace)
	Database::Cassandra::Client cass;
	const char* keyspace;
	
	CODE:
		RETVAL = cass_cluster_connect_keyspace(cass->cluster, keyspace);
	OUTPUT:
		RETVAL

void
cluster_free(cass)
	Database::Cassandra::Client cass;
	
	CODE:
		cass_cluster_free(cass->cluster);
		cass->cluster = NULL;


#***********************************************************************************
#*
#* Session
#*
#***********************************************************************************

CassFuture*
session_close(cass, session)
	Database::Cassandra::Client cass;
	CassSession *session;
	
	CODE:
		RETVAL = cass_session_close(session);
	OUTPUT:
		RETVAL

CassFuture*
session_prepare(cass, session, query)
	Database::Cassandra::Client cass;
	CassSession *session;
	SV *query;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		char *query_c = SvPV( query, len );
		CassString query_str = {query_c, (cass_size_t)len};
		
		RETVAL = cass_session_prepare(session, query_str);
	OUTPUT:
		RETVAL

CassFuture*
session_execute(cass, session, statement)
	Database::Cassandra::Client cass;
	CassSession *session;
	CassStatement *statement;
	
	CODE:
		RETVAL = cass_session_execute(session, statement);
	OUTPUT:
		RETVAL

CassFuture*
session_execute_batch(cass, session, batch)
	Database::Cassandra::Client cass;
	CassSession *session;
	CassBatch *batch;
	
	CODE:
		RETVAL = cass_session_execute_batch(session, batch);
	OUTPUT:
		RETVAL


#***********************************************************************************
#*
#* Future
#*
#***********************************************************************************

void
future_free(cass, future)
	Database::Cassandra::Client cass;
	CassFuture *future;
	
	CODE:
		cass_future_free(future);

CassError
future_set_callback(cass, future, callback, data = &PL_sv_undef)
	Database::Cassandra::Client cass;
	CassFuture *future;
	SV *callback;
	SV *data;
	
	CODE:
		SV *sub = newSVsv(callback);
		
		if(cass->callback_future)
		{
			sv_2mortal((SV *)cass->callback_future);
		}
		
		cass->callback_future = (void *)sub;
		cass->callback_future_arg = (void *)data;
		
		if(cass->perl_int == NULL)
			cass->perl_int = Perl_get_context();
		
		RETVAL = cass_future_set_callback(future, base_callback_future, (void *)cass);
	OUTPUT:
		RETVAL

SV*
future_ready(cass, future)
	Database::Cassandra::Client cass;
	CassFuture *future;
	
	CODE:
		RETVAL = newSViv( (int)cass_future_ready(future) );
	OUTPUT:
		RETVAL

SV*
future_wait(cass, future)
	Database::Cassandra::Client cass;
	CassFuture *future;
	
	CODE:
		cass_future_wait(future);
		RETVAL = newSViv(0);
	OUTPUT:
		RETVAL

SV*
future_wait_timed(cass, future, timeout)
	Database::Cassandra::Client cass;
	CassFuture *future;
	SV *timeout;
	
	CODE:
		RETVAL = newSViv( (int)cass_future_wait_timed( future, (cass_duration_t)(SvIV(timeout)) ) );
	OUTPUT:
		RETVAL

CassSession*
future_get_session(cass, future)
	Database::Cassandra::Client cass;
	CassFuture *future;
	
	CODE:
		RETVAL = cass_future_get_session(future);
	OUTPUT:
		RETVAL

CassResult*
future_get_result(cass, future)
	Database::Cassandra::Client cass;
	CassFuture *future;
	
	CODE:
		RETVAL = (CassResult *)cass_future_get_result(future);
	OUTPUT:
		RETVAL

CassPrepared*
future_get_prepared(cass, future)
	Database::Cassandra::Client cass;
	CassFuture *future;
	
	CODE:
		RETVAL = (CassPrepared*)cass_future_get_prepared(future);
	OUTPUT:
		RETVAL

CassError
future_error_code(cass, future)
	Database::Cassandra::Client cass;
	CassFuture *future;
	
	CODE:
		RETVAL = cass_future_error_code(future);
	OUTPUT:
		RETVAL

SV*
future_error_message(cass, future)
	Database::Cassandra::Client cass;
	CassFuture *future;
	
	CODE:
		CassString str = cass_future_error_message(future);
		RETVAL = newSVpv( str.data, str.length );
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* Statement
#*
#***********************************************************************************

CassStatement*
statement_new(cass, query, parameter_count)
	Database::Cassandra::Client cass;
	SV *query;
	SV *parameter_count;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		char *query_c = SvPV( query, len );
		CassString query_str = {query_c, (cass_size_t)len};
		
		RETVAL = cass_statement_new(query_str, (cass_size_t)SvUV(parameter_count));
	OUTPUT:
		RETVAL

void
statement_free(cass, statement)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	
	CODE:
		cass_statement_free(statement);

CassError
statement_set_consistency(cass, statement, consistency)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	int consistency;
	
	CODE:
		RETVAL = cass_statement_set_consistency(statement, consistency);
	OUTPUT:
		RETVAL

CassError
statement_set_serial_consistency(cass, statement, serial_consistency)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	int serial_consistency;
	
	CODE:
		RETVAL = cass_statement_set_serial_consistency(statement, serial_consistency);
	OUTPUT:
		RETVAL

CassError
statement_set_paging_size(cass, statement, page_size)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	int page_size;
	
	CODE:
		RETVAL = cass_statement_set_paging_size(statement, page_size);
	OUTPUT:
		RETVAL

CassError
statement_set_paging_state(cass, statement, result)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	CassResult *result;
	
	CODE:
		RETVAL = cass_statement_set_paging_state(statement, result);
	OUTPUT:
		RETVAL

CassError
statement_bind_null(cass, statement, index)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	
	CODE:
		RETVAL = cass_statement_bind_null(statement, (cass_size_t)SvUV(index));
	OUTPUT:
		RETVAL

CassError
statement_bind_int32(cass, statement, index, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	SV *value;
	
	CODE:
		RETVAL = cass_statement_bind_int32(statement, (cass_size_t)SvUV(index), (cass_int32_t)SvIV(value));
	OUTPUT:
		RETVAL

CassError
statement_bind_int64(cass, statement, index, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	SV *value;
	
	CODE:
		RETVAL = cass_statement_bind_int64(statement, (cass_size_t)SvUV(index), (cass_int64_t)SvIV(value));
	OUTPUT:
		RETVAL

CassError
statement_bind_float(cass, statement, index, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	SV *value;
	
	CODE:
		RETVAL = cass_statement_bind_float(statement, (cass_size_t)SvUV(index), (cass_float_t)SvNV(value));
	OUTPUT:
		RETVAL

CassError
statement_bind_double(cass, statement, index, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	SV *value;
	
	CODE:
		RETVAL = cass_statement_bind_double(statement, (cass_size_t)SvUV(index), (cass_float_t)SvNV(value));
	OUTPUT:
		RETVAL

CassError
statement_bind_bool(cass, statement, index, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	SV *value;
	
	CODE:
		RETVAL = cass_statement_bind_bool(statement, (cass_size_t)SvUV(index), (cass_bool_t)SvIV(value));
	OUTPUT:
		RETVAL

CassError
statement_bind_string(cass, statement, index, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	SV *value;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		const char *value_c = SvPV( value, len );
		CassString value_str = {value_c, (cass_size_t)len};
		
		RETVAL = cass_statement_bind_string(statement, (cass_size_t)SvUV(index), value_str);
	OUTPUT:
		RETVAL

CassError
statement_bind_bytes(cass, statement, index, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	SV *value;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		char *value_c = SvPV( value, len );
		CassBytes value_b = {(const unsigned char *)value_c, (cass_size_t)len};
		
		RETVAL = cass_statement_bind_bytes(statement, (cass_size_t)SvUV(index), value_b);
	OUTPUT:
		RETVAL

CassError
statement_bind_uuid(cass, statement, index, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	char *value;
	
	CODE:
		RETVAL = cass_statement_bind_uuid(statement, (cass_size_t)SvUV(index), (const unsigned char *)value);
	OUTPUT:
		RETVAL

CassError
statement_bind_inet(cass, statement, index, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	SV *value;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		char *value_c = SvPV( value, len );
		CassInet value_b = {(unsigned char)value_c, (cass_size_t)len};
		
		RETVAL = cass_statement_bind_inet(statement, (cass_size_t)SvUV(index), value_b);
	OUTPUT:
		RETVAL

CassError
statement_bind_decimal(cass, statement, index, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	SV *value;
	
	CODE:
        HV *myhash = (HV *)SvRV(value);
        SV **k_scale  = hv_fetch(myhash, "scale", 5, 0);
		SV **k_varint = hv_fetch(myhash, "varint", 6, 0);
		
		cass_int32_t scale = SvIV(*k_scale);
		
		STRLEN len;
		char *bytes = SvPV(*k_varint, len);
		
		CassBytes varint = {(const unsigned char *)bytes, (cass_size_t)len};
		CassDecimal decimal = {scale, varint};
		
		RETVAL = cass_statement_bind_decimal(statement, (cass_size_t)SvUV(index), decimal);
	OUTPUT:
		RETVAL

CassError
statement_bind_custom(cass, statement, index, data)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	SV *data;
	
	CODE:
		STRLEN n_len;
		unsigned char *data_c = (unsigned char *)SvPV(data, n_len);
		
		cass_byte_t *output_p = NULL;
		RETVAL = cass_statement_bind_custom(statement, (cass_size_t)SvUV(index), n_len, &output_p);
		
		if(RETVAL == CASS_OK)
		{
			cass_size_t i;
			for(i = 0; i < n_len; i++)
			{
				output_p[i] = data_c[i];
			}
		}
		
	OUTPUT:
		RETVAL

CassError
statement_bind_collection(cass, statement, index, collection)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	SV *index;
	CassCollection* collection;
	
	CODE:
		RETVAL = cass_statement_bind_collection(statement, (cass_size_t)SvUV(index), collection);
	OUTPUT:
		RETVAL

CassError
statement_bind_int32_by_name(cass, statement, name, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char* name;
	SV *value;
	
	CODE:
		RETVAL = cass_statement_bind_int32_by_name(statement, name, (cass_int32_t)SvIV(value));
	OUTPUT:
		RETVAL

CassError
statement_bind_int64_by_name(cass, statement, name, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char* name;
	SV *value;
	
	CODE:
		RETVAL = cass_statement_bind_int64_by_name(statement, name, (cass_int64_t)SvIV(value));
	OUTPUT:
		RETVAL

CassError
statement_bind_float_by_name(cass, statement, name, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char* name;
	SV *value;
	
	CODE:
		RETVAL = cass_statement_bind_float_by_name(statement, name, (cass_float_t)SvNV(value));
	OUTPUT:
		RETVAL

CassError
statement_bind_double_by_name(cass, statement, name, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char* name;
	SV *value;
	
	CODE:
		RETVAL = cass_statement_bind_double_by_name(statement, name, (cass_float_t)SvNV(value));
	OUTPUT:
		RETVAL

CassError
statement_bind_bool_by_name(cass, statement, name, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char* name;
	SV *value;
	
	CODE:
		RETVAL = cass_statement_bind_bool_by_name(statement, name, (cass_bool_t)SvIV(value));
	OUTPUT:
		RETVAL

CassError
statement_bind_string_by_name(cass, statement, name, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char* name;
	SV *value;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		const char *value_c = SvPV( value, len );
		CassString value_str = {value_c, (cass_size_t)len};
		
		RETVAL = cass_statement_bind_string_by_name(statement, name, value_str);
	OUTPUT:
		RETVAL

CassError
statement_bind_bytes_by_name(cass, statement, name, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char *name;
	SV *value;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		char *value_c = SvPV( value, len );
		CassBytes value_b = {(const unsigned char *)value_c, (cass_size_t)len};
		
		RETVAL = cass_statement_bind_bytes_by_name(statement, name, value_b);
	OUTPUT:
		RETVAL

CassError
statement_bind_uuid_by_name(cass, statement, name, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char *name;
	char *value;
	
	CODE:
		RETVAL = cass_statement_bind_uuid_by_name(statement, name, (const unsigned char *)value);
	OUTPUT:
		RETVAL

CassError
statement_bind_inet_by_name(cass, statement, name, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char *name;
	SV *value;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		char *value_c = SvPV( value, len );
		CassInet value_b = {(unsigned char)value_c, (cass_size_t)len};
		
		RETVAL = cass_statement_bind_inet_by_name(statement, name, value_b);
	OUTPUT:
		RETVAL

CassError
statement_bind_decimal_by_name(cass, statement, name, value)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char *name;
	SV *value;
	
	CODE:
        HV *myhash = (HV *)SvRV(value);
        SV **k_scale  = hv_fetch(myhash, "scale", 5, 0);
		SV **k_varint = hv_fetch(myhash, "varint", 6, 0);
		
		cass_int32_t scale = SvIV(*k_scale);
		
		STRLEN len;
		char *bytes = SvPV(*k_varint, len);
		
		CassBytes varint = {(const unsigned char *)bytes, (cass_size_t)len};
		CassDecimal decimal = {scale, varint};
		
		RETVAL = cass_statement_bind_decimal_by_name(statement, name, decimal);
	OUTPUT:
		RETVAL

CassError
statement_bind_custom_by_name(cass, statement, name, data)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char *name;
	SV *data;
	
	CODE:
		STRLEN n_len;
		unsigned char *data_c = (unsigned char *)SvPV(data, n_len);
		
		cass_byte_t *output_p = NULL;
		RETVAL = cass_statement_bind_custom_by_name(statement, name, n_len, &output_p);
		
		if(RETVAL == CASS_OK)
		{
			cass_size_t i;
			for(i = 0; i < n_len; i++)
			{
				output_p[i] = data_c[i];
			}
		}
		
	OUTPUT:
		RETVAL

CassError
statement_bind_collection_by_name(cass, statement, name, collection)
	Database::Cassandra::Client cass;
	CassStatement *statement;
	const char *name;
	CassCollection* collection;
	
	CODE:
		RETVAL = cass_statement_bind_collection_by_name(statement, name, collection);
	OUTPUT:
		RETVAL


#***********************************************************************************
#*
#* Prepared
#*
#***********************************************************************************

void
prepared_free(cass, prepared)
	Database::Cassandra::Client cass;
	CassPrepared *prepared;
	
	CODE:
		cass_prepared_free(prepared);

CassStatement*
prepared_bind(cass, prepared)
	Database::Cassandra::Client cass;
	CassPrepared *prepared;
	
	CODE:
		RETVAL = cass_prepared_bind(prepared);
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* Batch
#*
#***********************************************************************************

CassBatch *
batch_new(cass, type)
	Database::Cassandra::Client cass;
	int type;
	
	CODE:
		RETVAL = cass_batch_new(type);
	OUTPUT:
		RETVAL

void
batch_free(cass, batch)
	Database::Cassandra::Client cass;
	CassBatch *batch;
	
	CODE:
		cass_batch_free(batch);

CassError
batch_set_consistency(cass, batch, consistency)
	Database::Cassandra::Client cass;
	CassBatch *batch;
	int consistency;
	
	CODE:
		RETVAL = cass_batch_set_consistency(batch, consistency);
	OUTPUT:
		RETVAL

CassError
batch_add_statement(cass, batch, statement)
	Database::Cassandra::Client cass;
	CassBatch *batch;
	CassStatement *statement;
	
	CODE:
		RETVAL = cass_batch_add_statement(batch, statement);
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* Collection
#*
#***********************************************************************************

CassCollection*
collection_new(cass, type, item_count)
	Database::Cassandra::Client cass;
	int type;
	SV *item_count;
	
	CODE:
		RETVAL = cass_collection_new((CassCollectionType)type, (cass_size_t)SvUV(item_count));
	OUTPUT:
		RETVAL

void
collection_free(cass, collection)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	
	CODE:
		cass_collection_free(collection);

CassError
collection_append_int32(cass, collection, value)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	SV *value;
	
	CODE:
		RETVAL = cass_collection_append_int32(collection, (cass_int32_t)SvIV(value));
	OUTPUT:
		RETVAL

CassError
collection_append_int64(cass, collection, value)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	SV *value;
	
	CODE:
		RETVAL = cass_collection_append_int64(collection, (cass_int64_t)SvIV(value));
	OUTPUT:
		RETVAL

CassError
collection_append_float(cass, collection, value)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	SV *value;
	
	CODE:
		RETVAL = cass_collection_append_float(collection, (cass_float_t)SvNV(value));
	OUTPUT:
		RETVAL

CassError
collection_append_double(cass, collection, value)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	SV *value;
	
	CODE:
		RETVAL = cass_collection_append_double(collection, (cass_double_t)SvNV(value));
	OUTPUT:
		RETVAL

CassError
collection_append_bool(cass, collection, value)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	SV *value;
	
	CODE:
		RETVAL = cass_collection_append_bool(collection, (cass_bool_t)SvIV(value));
	OUTPUT:
		RETVAL

CassError
collection_append_string(cass, collection, value)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	SV *value;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		const char *value_c = SvPV( value, len );
		CassString value_str = {value_c, (cass_size_t)len};
		
		RETVAL = cass_collection_append_string(collection, value_str);
	OUTPUT:
		RETVAL

CassError
collection_append_bytes(cass, collection, value)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	SV *value;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		const char *value_c = SvPV( value, len );
		CassBytes value_bstr = {(const unsigned char *)value_c, (cass_size_t)len};
		
		RETVAL = cass_collection_append_bytes(collection, value_bstr);
	OUTPUT:
		RETVAL

CassError
collection_append_uuid(cass, collection, value)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	SV *value;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		char *uuid = SvPV(value, len);
		RETVAL = cass_collection_append_uuid(collection, (unsigned char *)uuid);
	OUTPUT:
		RETVAL

CassError
collection_append_inet(cass, collection, value)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	SV *value;
	
	PREINIT:
		STRLEN len = 0;
	CODE:
		char *value_c = SvPV( value, len );
		CassInet value_b = {(unsigned char)value_c, (cass_size_t)len};
		
		RETVAL = cass_collection_append_inet(collection, value_b);
	OUTPUT:
		RETVAL

CassError
collection_append_decimal(cass, collection, value)
	Database::Cassandra::Client cass;
	CassCollection *collection;
	SV *value;
	
	CODE:
        HV *myhash = (HV *)SvRV(value);
		
        SV **k_scale  = hv_fetch(myhash, "scale", 5, 0);
		SV **k_varint = hv_fetch(myhash, "varint", 6, 0);
		
		cass_int32_t scale = SvIV(*k_scale);
		
		STRLEN len;
		char *bytes = SvPV(*k_varint, len);
		
		CassBytes varint = {(const unsigned char *)bytes, (cass_size_t)len};
		CassDecimal decimal = {scale, varint};
		
		RETVAL = cass_collection_append_decimal(collection, decimal);
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* Result
#*
#***********************************************************************************

void
result_free(cass, result)
	Database::Cassandra::Client cass;
	CassResult* result;
	
	CODE:
		cass_result_free(result);

SV*
result_row_count(cass, result)
	Database::Cassandra::Client cass;
	CassResult* result;
	
	CODE:
		RETVAL = newSVuv(cass_result_row_count(result));
	OUTPUT:
		RETVAL

SV*
result_column_count(cass, result)
	Database::Cassandra::Client cass;
	CassResult* result;
	
	CODE:
		RETVAL = newSVuv(cass_result_column_count(result));
	OUTPUT:
		RETVAL

SV*
result_column_name(cass, result, index)
	Database::Cassandra::Client cass;
	CassResult* result;
	SV *index;
	
	CODE:
		CassString str = cass_result_column_name(result, (cass_size_t)SvUV(index));
		RETVAL = newSVpv(str.data, str.length);
	OUTPUT:
		RETVAL

SV*
result_column_type(cass, result, index)
	Database::Cassandra::Client cass;
	CassResult* result;
	SV *index;
	
	CODE:
		RETVAL = newSViv( cass_result_column_type(result, (cass_size_t)SvUV(index)) );
	OUTPUT:
		RETVAL

CassRow*
result_first_row(cass, result)
	Database::Cassandra::Client cass;
	CassResult* result;
	
	CODE:
		RETVAL = (CassRow*)cass_result_first_row(result);
	OUTPUT:
		RETVAL

SV*
result_has_more_pages(cass, result)
	Database::Cassandra::Client cass;
	CassResult* result;
	
	CODE:
		RETVAL = newSViv( (int)cass_result_has_more_pages(result) );
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* Iterator
#*
#***********************************************************************************

CassIterator*
iterator_from_result(cass, result)
	Database::Cassandra::Client cass;
	CassResult* result;
	
	CODE:
		RETVAL = cass_iterator_from_result(result);
	OUTPUT:
		RETVAL

CassIterator*
iterator_from_row(cass, row)
	Database::Cassandra::Client cass;
	CassRow* row;
	
	CODE:
		RETVAL = cass_iterator_from_row(row);
	OUTPUT:
		RETVAL

CassIterator*
iterator_from_collection(cass, value)
	Database::Cassandra::Client cass;
	CassValue* value;
	
	CODE:
		RETVAL = cass_iterator_from_collection(value);
	OUTPUT:
		RETVAL

CassIterator*
iterator_from_map(cass, value)
	Database::Cassandra::Client cass;
	CassValue* value;
	
	CODE:
		RETVAL = cass_iterator_from_map(value);
	OUTPUT:
		RETVAL

void
iterator_free(cass, iterator)
	Database::Cassandra::Client cass;
	CassIterator* iterator;
	
	CODE:
		cass_iterator_free(iterator);

SV*
iterator_next(cass, iterator)
	Database::Cassandra::Client cass;
	CassIterator* iterator;
	
	CODE:
		RETVAL = newSViv( (int)cass_iterator_next(iterator) );
	OUTPUT:
		RETVAL

CassRow*
iterator_get_row(cass, iterator)
	Database::Cassandra::Client cass;
	CassIterator* iterator;
	
	CODE:
		RETVAL = (CassRow*)cass_iterator_get_row(iterator);
	OUTPUT:
		RETVAL

CassValue*
iterator_get_column(cass, iterator)
	Database::Cassandra::Client cass;
	CassIterator* iterator;
	
	CODE:
		RETVAL = (CassValue*)cass_iterator_get_column(iterator);
	OUTPUT:
		RETVAL

CassValue*
iterator_get_value(cass, iterator)
	Database::Cassandra::Client cass;
	CassIterator* iterator;
	
	CODE:
		RETVAL = (CassValue*)cass_iterator_get_value(iterator);
	OUTPUT:
		RETVAL

CassValue*
iterator_get_map_key(cass, iterator)
	Database::Cassandra::Client cass;
	CassIterator* iterator;
	
	CODE:
		RETVAL = (CassValue*)cass_iterator_get_map_key(iterator);
	OUTPUT:
		RETVAL

CassValue*
iterator_get_map_value(cass, iterator)
	Database::Cassandra::Client cass;
	CassIterator* iterator;
	
	CODE:
		RETVAL = (CassValue*)cass_iterator_get_map_value(iterator);
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* Row
#*
#***********************************************************************************

CassValue*
row_get_column(cass, row, index)
	Database::Cassandra::Client cass;
	CassRow* row;
	SV *index;
	
	CODE:
		RETVAL = (CassValue*)cass_row_get_column(row, (cass_size_t)SvUV(index));
	OUTPUT:
		RETVAL

CassValue*
row_get_column_by_name(cass, row, name)
	Database::Cassandra::Client cass;
	CassRow* row;
	const char* name;
	
	CODE:
		RETVAL = (CassValue*)cass_row_get_column_by_name(row, name);
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* Value
#*
#***********************************************************************************

CassError
value_get_int32(cass, value, output)
	Database::Cassandra::Client cass;
	CassValue* value;
	SV* output;
	
	CODE:
		cass_int32_t s_output;
		RETVAL = cass_value_get_int32(value, &s_output);
		sv_setiv(output, s_output);
	OUTPUT:
		RETVAL

CassError
value_get_int64(cass, value, output)
	Database::Cassandra::Client cass;
	CassValue* value;
	SV* output;
	
	CODE:
		cass_int64_t s_output;
		RETVAL = cass_value_get_int64(value, &s_output);
		sv_setiv(output, s_output);
	OUTPUT:
		RETVAL

CassError
value_get_float(cass, value, output)
	Database::Cassandra::Client cass;
	CassValue* value;
	SV* output;
	
	CODE:
		cass_float_t s_output;
		RETVAL = cass_value_get_float(value, &s_output);
		sv_setnv(output, s_output);
	OUTPUT:
		RETVAL

CassError
value_get_double(cass, value, output)
	Database::Cassandra::Client cass;
	CassValue* value;
	SV* output;
	
	CODE:
		cass_double_t s_output;
		RETVAL = cass_value_get_double(value, &s_output);
		sv_setnv(output, s_output);
	OUTPUT:
		RETVAL

CassError
value_get_bool(cass, value, output)
	Database::Cassandra::Client cass;
	CassValue* value;
	SV* output;
	
	CODE:
		cass_bool_t s_output;
		RETVAL = cass_value_get_bool(value, &s_output);
		sv_setiv(output, s_output);
	OUTPUT:
		RETVAL

CassError
value_get_uuid(cass, value, output)
	Database::Cassandra::Client cass;
	CassValue* value;
	SV* output;
	
	CODE:
		CassUuid s_output;
		RETVAL = cass_value_get_uuid(value, s_output);
		
		SV *n_str = sv_2mortal( newSVpv((char *)(s_output), CASS_UUID_STRING_LENGTH) );
		STRLEN n_len;
		
		sv_setpv(output, SvPV(n_str, n_len));
	OUTPUT:
		RETVAL

CassError
value_get_inet(cass, value, output)
	Database::Cassandra::Client cass;
	CassValue* value;
	SV* output;
	
	CODE:
		CassInet s_output;
		RETVAL = cass_value_get_inet(value, &s_output);
		
		SV *n_str = sv_2mortal( newSVpv((char *)(s_output.address), s_output.address_length) );
		
		STRLEN n_len;
		sv_setpv(output, SvPV(n_str, n_len));
	OUTPUT:
		RETVAL

CassError
value_get_string(cass, value, output)
	Database::Cassandra::Client cass;
	CassValue* value;
	SV* output;
	
	CODE:
		CassString s_output;
		RETVAL = cass_value_get_string(value, &s_output);
		
		SV *n_str = sv_2mortal( newSVpv(s_output.data, s_output.length) );
		
		STRLEN n_len;
		sv_setpv(output, SvPV(n_str, n_len));
	OUTPUT:
		RETVAL

CassError
value_get_bytes(cass, value, output)
	Database::Cassandra::Client cass;
	CassValue* value;
	SV* output;
	
	CODE:
		CassBytes s_output;
		RETVAL = cass_value_get_bytes(value, &s_output);
		
		SV *n_str = sv_2mortal( newSVpv((char *)(s_output.data), s_output.size) );
		SvUTF8_off(n_str);
		
		STRLEN n_len;
		sv_setpv(output, SvPV(n_str, n_len));
	OUTPUT:
		RETVAL

CassError
value_get_decimal(cass, value, output)
	Database::Cassandra::Client cass;
	CassValue* value;
	HV* output;
	
	CODE:
		CassDecimal s_output;
		RETVAL = cass_value_get_decimal(value, &s_output);
		if(RETVAL == CASS_OK)
		{
			SV **ha;
			ha = hv_store(output, "scale", 5, newSViv(s_output.scale), 0);
			ha = hv_store(output, "bytes", 5, newSVpv((char *)(s_output.varint.data), s_output.varint.size), 0);
		}
	OUTPUT:
		RETVAL

SV*
value_type(cass, value)
	Database::Cassandra::Client cass;
	CassValue* value;
	
	CODE:
		RETVAL = newSViv( cass_value_type(value) );
	OUTPUT:
		RETVAL

SV*
value_type_name_by_code(cass, vtype)
	Database::Cassandra::Client cass;
	int vtype;
	
	CODE:
		switch(vtype)
		{
			case CASS_VALUE_TYPE_UNKNOWN: RETVAL = newSVpv( "UNKNOWN", 0 ); break;
			case CASS_VALUE_TYPE_CUSTOM: RETVAL = newSVpv( "CUSTOM", 0 ); break;
			case CASS_VALUE_TYPE_ASCII: RETVAL = newSVpv( "ASCII", 0 ); break;
			case CASS_VALUE_TYPE_BIGINT: RETVAL = newSVpv( "BIGINT", 0 ); break;
			case CASS_VALUE_TYPE_BLOB: RETVAL = newSVpv( "BLOB", 0 ); break;
			case CASS_VALUE_TYPE_BOOLEAN: RETVAL = newSVpv( "BOOLEAN", 0 ); break;
			case CASS_VALUE_TYPE_COUNTER: RETVAL = newSVpv( "COUNTER", 0 ); break;
			case CASS_VALUE_TYPE_DECIMAL: RETVAL = newSVpv( "DECIMAL", 0 ); break;
			case CASS_VALUE_TYPE_DOUBLE: RETVAL = newSVpv( "DOUBLE", 0 ); break;
			case CASS_VALUE_TYPE_FLOAT: RETVAL = newSVpv( "FLOAT", 0 ); break;
			case CASS_VALUE_TYPE_INT: RETVAL = newSVpv( "INT", 0 ); break;
			case CASS_VALUE_TYPE_TEXT: RETVAL = newSVpv( "TEXT", 0 ); break;
			case CASS_VALUE_TYPE_TIMESTAMP: RETVAL = newSVpv( "TIMESTAMP", 0 ); break;
			case CASS_VALUE_TYPE_UUID: RETVAL = newSVpv( "UUID", 0 ); break;
			case CASS_VALUE_TYPE_VARCHAR: RETVAL = newSVpv( "VARCHAR", 0 ); break;
			case CASS_VALUE_TYPE_VARINT: RETVAL = newSVpv( "VARINT", 0 ); break;
			case CASS_VALUE_TYPE_TIMEUUID: RETVAL = newSVpv( "TIMEUUID", 0 ); break;
			case CASS_VALUE_TYPE_INET: RETVAL = newSVpv( "INET", 0 ); break;
			case CASS_VALUE_TYPE_LIST: RETVAL = newSVpv( "LIST", 0 ); break;
			case CASS_VALUE_TYPE_MAP: RETVAL = newSVpv( "MAP", 0 ); break;
			case CASS_VALUE_TYPE_SET: RETVAL = newSVpv( "SET", 0 ); break;
			default: RETVAL = newSVpv( "UNKNOWN", 0 ); break;
		}
		
	OUTPUT:
		RETVAL

SV*
value_is_null(cass, value)
	Database::Cassandra::Client cass;
	CassValue* value;
	
	CODE:
		RETVAL = newSViv( cass_value_is_null(value) );
	OUTPUT:
		RETVAL

SV*
value_primary_sub_type(cass, collection)
	Database::Cassandra::Client cass;
	CassValue* collection;
	
	CODE:
		RETVAL = newSViv( cass_value_primary_sub_type(collection) );
	OUTPUT:
		RETVAL

SV*
value_secondary_sub_type(cass, collection)
	Database::Cassandra::Client cass;
	CassValue* collection;
	
	CODE:
		RETVAL = newSViv( cass_value_secondary_sub_type(collection) );
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* UUID
#*
#************************************************************************************

void
uuid_generate_time(cass, output)
	Database::Cassandra::Client cass;
	SV* output;
	
	CODE:
		CassUuid s_output;
		cass_uuid_generate_time(s_output);
		
		SV *n_str = sv_2mortal( newSVpv((char *)(s_output), CASS_UUID_STRING_LENGTH) );
		SvUTF8_off(n_str);
		
		STRLEN n_len;
		sv_setpv(output, SvPV(n_str, n_len));

void
uuid_from_time(cass, time, output)
	Database::Cassandra::Client cass;
	SV *time;
	SV *output;
	
	CODE:
		CassUuid s_output;
		cass_uuid_from_time((cass_uint64_t)SvIV(time), s_output);
		
		SV *n_str = sv_2mortal( newSVpv((char *)(s_output), CASS_UUID_STRING_LENGTH) );
		SvUTF8_off(n_str);
		
		STRLEN n_len;
		sv_setpv(output, SvPV(n_str, n_len));

void
uuid_min_from_time(cass, time, output)
	Database::Cassandra::Client cass;
	SV *time;
	SV *output;
	
	CODE:
		CassUuid s_output;
		cass_uuid_min_from_time((cass_uint64_t)SvIV(time), s_output);
		
		SV *n_str = sv_2mortal( newSVpv((char *)(s_output), CASS_UUID_STRING_LENGTH) );
		SvUTF8_off(n_str);
		
		STRLEN n_len;
		sv_setpv(output, SvPV(n_str, n_len));

void
uuid_max_from_time(cass, time, output)
	Database::Cassandra::Client cass;
	SV *time;
	SV *output;
	
	CODE:
		CassUuid s_output;
		cass_uuid_max_from_time((cass_uint64_t)SvIV(time), s_output);
		
		SV *n_str = sv_2mortal( newSVpv((char *)(s_output), CASS_UUID_STRING_LENGTH) );
		SvUTF8_off(n_str);
		
		STRLEN n_len;
		sv_setpv(output, SvPV(n_str, n_len));

void
uuid_generate_random(cass, output)
	Database::Cassandra::Client cass;
	SV* output;
	
	CODE:
		CassUuid s_output;
		cass_uuid_generate_random(s_output);
		
		SV *n_str = sv_2mortal( newSVpv((char *)(s_output), CASS_UUID_STRING_LENGTH) );
		SvUTF8_off(n_str);
		
		STRLEN n_len;
		sv_setpv(output, SvPV(n_str, n_len));

SV*
uuid_timestamp(cass, uuid)
	Database::Cassandra::Client cass;
	char *uuid;
	
	CODE:
		cass_uint64_t timestamp = cass_uuid_timestamp((unsigned char *)uuid);
		RETVAL = newSViv(timestamp);
	
	OUTPUT:
		RETVAL


SV*
uuid_version(cass, uuid)
	Database::Cassandra::Client cass;
	char *uuid;
	
	CODE:
		cass_uint8_t version = cass_uuid_version((unsigned char *)uuid);
		RETVAL = newSVpv((char *)&version, 1);
	
	OUTPUT:
		RETVAL

void
uuid_string(cass, uuid, output)
	Database::Cassandra::Client cass;
	SV *output;
	char *uuid;
	
	CODE:
		char c_out[CASS_UUID_STRING_LENGTH];
		cass_uuid_string((unsigned char *)uuid, c_out);
		
		SV *n_str = sv_2mortal( newSVpv(c_out, CASS_UUID_STRING_LENGTH) );
		
		STRLEN n_len;
		sv_setpv(output, SvPV(n_str, n_len));


#***********************************************************************************
#*
#* Error
#*
#***********************************************************************************

SV*
error_desc(cass, error_code)
	Database::Cassandra::Client cass;
	int error_code;
	
	CODE:
		RETVAL = newSVpv( cass_error_desc(error_code), 0 );
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* Log level
#*
#***********************************************************************************

SV*
log_level_string(cass, log_level)
	Database::Cassandra::Client cass;
	int log_level;
	
	CODE:
		RETVAL = newSVpv(cass_log_level_string(log_level), 0);
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* Inet
#*
#************************************************************************************

SV*
inet_init_v4(cass, data)
	Database::Cassandra::Client cass;
	char *data;
	
	CODE:
		CassInet str = cass_inet_init_v4((unsigned char *)data);
		RETVAL = newSVpv((char *)str.address, CASS_INET_V4_LENGTH);
	OUTPUT:
		RETVAL

SV*
inet_init_v6(cass, data)
	Database::Cassandra::Client cass;
	char *data;
	
	CODE:
		CassInet str = cass_inet_init_v6((unsigned char *)data);
		RETVAL = newSVpv((char *)str.address, CASS_INET_V6_LENGTH);
	OUTPUT:
		RETVAL

#***********************************************************************************
#*
#* Decimal
#*
#************************************************************************************

SV*
decimal_init(cass, scale, varint)
	Database::Cassandra::Client cass;
	SV *scale;
	SV *varint;
	
	PREINIT:
		STRLEN len;
	CODE:
		char *varint_s = SvPV(varint, len);
		CassBytes varint_n = {(unsigned char *)varint_s, len};
		CassDecimal str = cass_decimal_init(SvIV(scale), varint_n);
		
		SV **ha;
		HV *hash = newHV();
		
		ha = hv_store(hash, "scale", 5, newSVsv(scale), 0);
		ha = hv_store(hash, "bytes", 5, newSVpv((char *)str.varint.data, str.varint.size), 0);
		
		RETVAL = newRV_noinc((SV *)hash);
	OUTPUT:
		RETVAL


#***********************************************************************************
#*
#* Bytes/String
#*
#************************************************************************************

SV*
bytes_init(cass, data, size)
	Database::Cassandra::Client cass;
	char* data;
	SV *size;
	
	CODE:
		CassBytes str = cass_bytes_init((unsigned char *)data, (cass_size_t)SvIV(size));
		RETVAL = newSVpv((char *)str.data, str.size);
	OUTPUT:
		RETVAL

SV*
string_init(cass, string)
	Database::Cassandra::Client cass;
	const char* string;
	
	CODE:
		CassString str = cass_string_init(string);
		RETVAL = newSVpv(str.data, str.length);
	OUTPUT:
		RETVAL

SV*
string_init2(cass, string, length)
	Database::Cassandra::Client cass;
	const char* string;
	SV *length;
	
	CODE:
		CassString str = cass_string_init2(string, (cass_size_t)SvIV(length));
		RETVAL = newSVpv(str.data, str.length);
	OUTPUT:
		RETVAL


#***********************************************************************************
#*
#* Destroy Perl Object
#*
#***********************************************************************************

void
DESTROY(cass)
	Database::Cassandra::Client cass;
	
	CODE:
		if(cass)
			free(cass);

#***********************************************************************************
#*
#* Const
#*
#***********************************************************************************

SV*
CASS_CONSISTENCY_ANY()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_ANY );
	OUTPUT:
		RETVAL


SV*
CASS_CONSISTENCY_ONE()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_ONE );
	OUTPUT:
		RETVAL


SV*
CASS_CONSISTENCY_TWO()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_TWO );
	OUTPUT:
		RETVAL


SV*
CASS_CONSISTENCY_THREE()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_THREE );
	OUTPUT:
		RETVAL


SV*
CASS_CONSISTENCY_QUORUM()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_QUORUM );
	OUTPUT:
		RETVAL


SV*
CASS_CONSISTENCY_ALL()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_ALL );
	OUTPUT:
		RETVAL


SV*
CASS_CONSISTENCY_LOCAL_QUORUM()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_LOCAL_QUORUM );
	OUTPUT:
		RETVAL


SV*
CASS_CONSISTENCY_EACH_QUORUM()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_EACH_QUORUM );
	OUTPUT:
		RETVAL


SV*
CASS_CONSISTENCY_SERIAL()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_SERIAL );
	OUTPUT:
		RETVAL


SV*
CASS_CONSISTENCY_LOCAL_SERIAL()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_LOCAL_SERIAL );
	OUTPUT:
		RETVAL


SV*
CASS_CONSISTENCY_LOCAL_ONE()
	CODE:
		RETVAL = newSViv( CASS_CONSISTENCY_LOCAL_ONE );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_UNKNOWN()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_UNKNOWN );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_CUSTOM()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_CUSTOM );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_ASCII()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_ASCII );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_BIGINT()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_BIGINT );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_BLOB()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_BLOB );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_BOOLEAN()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_BOOLEAN );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_COUNTER()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_COUNTER );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_DECIMAL()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_DECIMAL );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_DOUBLE()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_DOUBLE );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_FLOAT()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_FLOAT );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_INT()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_INT );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_TEXT()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_TEXT );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_TIMESTAMP()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_TIMESTAMP );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_UUID()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_UUID );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_VARCHAR()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_VARCHAR );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_VARINT()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_VARINT );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_TIMEUUID()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_TIMEUUID );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_INET()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_INET );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_LIST()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_LIST );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_MAP()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_MAP );
	OUTPUT:
		RETVAL

SV*
CASS_VALUE_TYPE_SET()
	CODE:
		RETVAL = newSViv( CASS_VALUE_TYPE_SET );
	OUTPUT:
		RETVAL

SV*
CASS_COLLECTION_TYPE_LIST()
	CODE:
		RETVAL = newSViv( CASS_COLLECTION_TYPE_LIST );
	OUTPUT:
		RETVAL

SV*
CASS_COLLECTION_TYPE_MAP()
	CODE:
		RETVAL = newSViv( CASS_COLLECTION_TYPE_MAP );
	OUTPUT:
		RETVAL

SV*
CASS_COLLECTION_TYPE_SET()
	CODE:
		RETVAL = newSViv( CASS_COLLECTION_TYPE_SET );
	OUTPUT:
		RETVAL

SV*
CASS_BATCH_TYPE_LOGGED()
	CODE:
		RETVAL = newSViv( CASS_BATCH_TYPE_LOGGED );
	OUTPUT:
		RETVAL

SV*
CASS_BATCH_TYPE_UNLOGGED()
	CODE:
		RETVAL = newSViv( CASS_BATCH_TYPE_UNLOGGED );
	OUTPUT:
		RETVAL

SV*
CASS_BATCH_TYPE_COUNTER()
	CODE:
		RETVAL = newSViv( CASS_BATCH_TYPE_COUNTER );
	OUTPUT:
		RETVAL

SV*
CASS_COMPRESSION_NONE()
	CODE:
		RETVAL = newSViv( CASS_COMPRESSION_NONE );
	OUTPUT:
		RETVAL

SV*
CASS_COMPRESSION_SNAPPY()
	CODE:
		RETVAL = newSViv( CASS_COMPRESSION_SNAPPY );
	OUTPUT:
		RETVAL

SV*
CASS_COMPRESSION_LZ4()
	CODE:
		RETVAL = newSViv( CASS_COMPRESSION_LZ4 );
	OUTPUT:
		RETVAL

SV*
CASS_LOG_DISABLED()
	CODE:
		RETVAL = newSViv( CASS_LOG_DISABLED );
	OUTPUT:
		RETVAL

SV*
CASS_LOG_CRITICAL()
	CODE:
		RETVAL = newSViv( CASS_LOG_CRITICAL );
	OUTPUT:
		RETVAL

SV*
CASS_LOG_ERROR()
	CODE:
		RETVAL = newSViv( CASS_LOG_ERROR );
	OUTPUT:
		RETVAL

SV*
CASS_LOG_WARN()
	CODE:
		RETVAL = newSViv( CASS_LOG_WARN );
	OUTPUT:
		RETVAL

SV*
CASS_LOG_INFO()
	CODE:
		RETVAL = newSViv( CASS_LOG_INFO );
	OUTPUT:
		RETVAL

SV*
CASS_LOG_DEBUG()
	CODE:
		RETVAL = newSViv( CASS_LOG_DEBUG );
	OUTPUT:
		RETVAL

SV*
CASS_LOG_LAST_ENTRY()
	CODE:
		RETVAL = newSViv( CASS_LOG_LAST_ENTRY );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SOURCE_NONE()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SOURCE_NONE );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SOURCE_LIB()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SOURCE_LIB );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SOURCE_SERVER()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SOURCE_SERVER );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SOURCE_SSL()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SOURCE_SSL );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SOURCE_COMPRESSION()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SOURCE_COMPRESSION );
	OUTPUT:
		RETVAL

SV*
CASS_OK()
	CODE:
		RETVAL = newSViv( CASS_OK );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_BAD_PARAMS()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_BAD_PARAMS );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_NO_STREAMS()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_NO_STREAMS );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_UNABLE_TO_INIT()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_UNABLE_TO_INIT );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_MESSAGE_ENCODE()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_MESSAGE_ENCODE );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_HOST_RESOLUTION()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_HOST_RESOLUTION );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_UNEXPECTED_RESPONSE()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_UNEXPECTED_RESPONSE );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_REQUEST_QUEUE_FULL()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_REQUEST_QUEUE_FULL );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_NO_AVAILABLE_IO_THREAD()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_NO_AVAILABLE_IO_THREAD );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_WRITE_ERROR()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_WRITE_ERROR );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_NO_HOSTS_AVAILABLE()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_NO_HOSTS_AVAILABLE );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_INDEX_OUT_OF_BOUNDS()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_INDEX_OUT_OF_BOUNDS );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_INVALID_ITEM_COUNT()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_INVALID_ITEM_COUNT );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_INVALID_VALUE_TYPE()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_INVALID_VALUE_TYPE );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_REQUEST_TIMED_OUT()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_REQUEST_TIMED_OUT );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_UNABLE_TO_SET_KEYSPACE()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_UNABLE_TO_SET_KEYSPACE );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_CALLBACK_ALREADY_SET()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_CALLBACK_ALREADY_SET );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_INVALID_STATEMENT_TYPE()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_INVALID_STATEMENT_TYPE );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_NAME_DOES_NOT_EXIST()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_NAME_DOES_NOT_EXIST );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_UNABLE_TO_DETERMINE_PROTOCOL()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_UNABLE_TO_DETERMINE_PROTOCOL );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_NULL_VALUE()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_NULL_VALUE );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LIB_NOT_IMPLEMENTED()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LIB_NOT_IMPLEMENTED );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_SERVER_ERROR()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_SERVER_ERROR );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_PROTOCOL_ERROR()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_PROTOCOL_ERROR );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_BAD_CREDENTIALS()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_BAD_CREDENTIALS );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_UNAVAILABLE()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_UNAVAILABLE );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_OVERLOADED()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_OVERLOADED );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_IS_BOOTSTRAPPING()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_IS_BOOTSTRAPPING );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_TRUNCATE_ERROR()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_TRUNCATE_ERROR );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_WRITE_TIMEOUT()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_WRITE_TIMEOUT );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_READ_TIMEOUT()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_READ_TIMEOUT );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_SYNTAX_ERROR()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_SYNTAX_ERROR );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_UNAUTHORIZED()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_UNAUTHORIZED );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_INVALID_QUERY()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_INVALID_QUERY );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_CONFIG_ERROR()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_CONFIG_ERROR );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_ALREADY_EXISTS()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_ALREADY_EXISTS );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SERVER_UNPREPARED()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SERVER_UNPREPARED );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SSL_INVALID_CERT()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SSL_INVALID_CERT );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SSL_INVALID_PRIVATE_KEY()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SSL_INVALID_PRIVATE_KEY );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SSL_NO_PEER_CERT()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SSL_NO_PEER_CERT );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SSL_INVALID_PEER_CERT()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SSL_INVALID_PEER_CERT );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_SSL_IDENTITY_MISMATCH()
	CODE:
		RETVAL = newSViv( CASS_ERROR_SSL_IDENTITY_MISMATCH );
	OUTPUT:
		RETVAL

SV*
CASS_ERROR_LAST_ENTRY()
	CODE:
		RETVAL = newSViv( CASS_ERROR_LAST_ENTRY );
	OUTPUT:
		RETVAL

