#!/usr/bin/python3
# -*- coding: utf-8 -*-

# author : Florent Kaisser <florent@kaisser.name>
# maintainer : Kiwix

import MySQLdb
import sqlite3
import sys
import datetime

KEY_NONE = 0
KEY_PRIMARY = 1
KEY_INDEX = 2
KEY_UNIQUE = 3

def typeToSQLite(type_sql):
  if ( "int" in type_sql ):
    return "INTEGER"
  elif ("char" in type_sql or "varbinary(255)" in type_sql or "text" in type_sql or "clob" in type_sql or "enum" in type_sql):
    return "TEXT"
  elif ("blob" in type_sql or "binary" in type_sql):
    return "BLOB"
  elif ("double" in type_sql or "float" in type_sql or "real" in type_sql):
    return "REAL"
  else:
    return type_sql;

def tableFieldToSQLite(name,type_sql,null,key,default,auto_increment):
  type_sqlite =  typeToSQLite(type_sql)
  r = "%s %s " % (name,type_sqlite)
  if (not null) : 
    r += "NOT NULL "
  if (default != None and key != KEY_PRIMARY) :
    if (type_sqlite != "INTEGER" or type_sqlite != "REAL"): 
      default = "'"+default.rstrip(" \t\r\n\0")+"'"
    r += "DEFAULT (" + default + ") "
  if (auto_increment):
    r += "PRIMARY KEY AUTOINCREMENT"
  return r
  
def tableFieldStrToSQLite(name,type_sql,null_str,key_str,default,ext):  
  if(null_str=='YES'): null = True
  if(null_str=='NO'): null = False
  
  if(key_str=='PRI'): key = KEY_PRIMARY
  elif(key_str=='UNI'): key = KEY_UNIQUE
  elif(key_str=='MUL'): key = KEY_INDEX
  else: key = KEY_NONE
  
  auto_increment = ('auto_increment' in ext)
  
  return tableFieldToSQLite(name,type_sql,null,key,default,auto_increment)
  
def genSQLiteCreateTable(t_name,fields):
  r = "CREATE TABLE " + t_name + " ("
  first = True
  for name,type_sql,null_str,key_str,default,ext in fields:
    if (first):
      first = False
    else :
      r+= ", "
    r += tableFieldStrToSQLite(name,type_sql,null_str,key_str,default,ext)
  r += ");"
  return r
  
def exportDatas(cmysql,csqlite,t_name):
  # get all row
  cmysql.execute("SELECT * FROM %s WHERE 1" % t_name)
  for row in cmysql.fetchall():
    vals = []
    for v in row:
      if(v is not None):
        if(type(v) == bytes):
          v = v.decode('utf-8')
        if (type(v) == datetime.datetime):
          v = str(v)
        if(type(v) == str):
          v = "'%s'" % v.replace("'","''").replace("\0","\\0")
      else:
        v = "NULL"
      vals.append(str(v))
    r = ("INSERT INTO %s VALUES (" % t_name) + ', '.join(vals) + ")"
    #print (r)
    csqlite.execute(r)
    
def exportIndexes(cmysql,csqlite,t_name):
  def endingRequest(r):
    r += ");"
    #print (r)
    csqlite.execute(r)
    
  def begingRequest(table, non_unique, key, first_column):
    r = "CREATE "
    if(not non_unique):
      r += "UNIQUE "
    return r + "INDEX %s ON %s (%s" % (table+"_"+key, table, first_column)

  # get all index
  cmysql.execute("SHOW INDEX FROM " + t_name)
  r=""
  for table,non_unique,key,seq,column,collation,card,sub,pack,null_str,index,comm,ind_comm in cmysql.fetchall():
    # do not add INDEX for the primary key (already declared in table creation with AUTOINCREMENT)
    if (key != "PRIMARY"):
      if(seq == 1):
        #this is the begining of a news index, ending of previous request
        if(r): endingRequest(r)
        # begining a new request build with first column
        r = begingRequest(table,non_unique,key,column)
      else:
        # add column of current request build
        r += ", %s" % column
  #ending for the last collumn
  if(r): endingRequest(r)
  
def exportTable(cmysql,csqlite,t_name):
    cmysql.execute("DESC " + t_name)
    r=genSQLiteCreateTable(t_name,cmysql.fetchall())
    csqlite.execute(r)
    
def exportTables(cmysql,csqlite,ignore_table_name):
  cmysql.execute("SHOW TABLES")
  
  for t in cmysql.fetchall():
    t_name = t[0]
    if(ignore_table_name not in t_name):
      print ("Process " + t_name)
      exportTable(cmysql,csqlite,t_name)
      exportIndexes(cmysql,csqlite,t_name)
      exportDatas(cmysql,csqlite,t_name)


def exportDatabase(host,user,passwd,db,sqlitefile,ignore_table_name):
  connectMySQL = MySQLdb.connect(host = host,user = user,passwd = passwd, charset='utf8')  
  cmysql = connectMySQL.cursor()
  cmysql.execute("USE "+ db)
  
  connectSQLite = sqlite3.connect(sqlitefile)
  csqlite = connectSQLite.cursor()
  csqlite.execute ("PRAGMA synchronous = OFF;")
  csqlite.execute ("PRAGMA journal_mode = MEMORY;")
  exportTables(cmysql,csqlite,ignore_table_name)

def main():
  exportDatabase('localhost','root','siret','www_openzim_org','test.sqlite','cache')
  
if __name__ == "__main__":
  main()

