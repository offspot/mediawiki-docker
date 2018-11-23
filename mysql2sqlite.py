#!/usr/bin/python3
# -*- coding: utf-8 -*-

# author : Florent Kaisser <florent@kaisser.name>
# maintainer : Kiwix

import MySQLdb
import sqlite3
import sys
import sqlite3

KEY_NONE = 0
KEY_PRIMARY = 1
KEY_INDEX = 2
KEY_UNIQUE = 3

def typeToSQLite(type_sql):
  if ( "int" in type_sql ):
    return "INTEGER"
  elif ("char" in type_sql or "binary" in type_sql or "text" in type_sql or "clob" in type_sql or "enum" in type_sql):
    return "TEXT"
  elif ("blob" in type_sql):
    return "BLOB"
  elif ("double" in type_sql or "float" in type_sql or "real" in type_sql):
    return "REAL"
  else:
    return "NUMERIC"

def toSQLite(name,type_sql,null,key,default,auto_increment):
  type_sqlite =  typeToSQLite(type_sql)
  r = "%s %s " % (name,type_sqlite)
  if (default != None and key != KEY_PRIMARY) :
    if (type_sqlite == "TEXT"): 
      default = "'"+default.rstrip(" \t\r\n\0")+"'"
    r += "DEFAULT (" + default + ") "
#  if( key == KEY_PRIMARY ):
#    r += "PRIMARY KEY "
#  elif( key == KEY_UNIQUE ):
#    r += "UNIQUE "
#  if (not null and not auto_increment) : 
#    r += "NOT NULL "
  if (auto_increment):
    r += "PRIMARY KEY AUTOINCREMENT"
  return r
    
connectMySQL = MySQLdb.connect(host = 'localhost',user = 'root',passwd = 'siret')
connectSQLite = sqlite3.connect('test.sqlite')
cmysql = connectMySQL.cursor()
cmysql.execute("USE www_openzim_org")
cmysql.execute("SHOW TABLES")
csqlite = connectSQLite.cursor()

for t in cmysql.fetchall():
  t_name = t[0]
  cmysql.execute("DESC " + t_name)
  r = "CREATE TABLE " + t_name + " ("
  first = True
  # print  (cmysql.fetchall())
  for name,type_sql,null_str,key_str,default,ext in cmysql.fetchall():
    if(null_str=='YES'): null = True
    if(null_str=='NO'): null = False
    
    if(key_str=='PRI'): key = KEY_PRIMARY
    elif(key_str=='UNI'): key = KEY_UNIQUE
    elif(key_str=='MUL'): key = KEY_INDEX
    else: key = KEY_NONE
    
    #print (type_sql)
    
    auto_increment = ('auto_increment' in ext) 
    
    if (first):
      first = False
    else : 
      r+= ", " 
    r += toSQLite(name,type_sql,null,key,default,auto_increment)
    
  r += ");"
  print (r)
  csqlite.execute(r)
  
  
