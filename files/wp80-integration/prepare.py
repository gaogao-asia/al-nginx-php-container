import subprocess,pathlib,os,secrets,re,json,hashlib,sys,tempfile
os.umask(0o077)
tmp=pathlib.Path(tempfile.mkdtemp(prefix='gbc-wp80-prepare-'))
print('Private preparation directory:',tmp)
src=pathlib.Path(sys.argv[1]).resolve()
if not (src/'wp-config.php').is_file(): raise SystemExit('Source WordPress config missing')
dst=pathlib.Path(os.environ['DOCKER_VOLUME_DIR'])/'wp-only1-multi-php80-integration'
def run(a,**kw): return subprocess.run(a,check=True,**kw)
def sql(q):
 return run(['docker','exec','-i','local-db','sh','-c','MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot --batch --skip-column-names'],input=q.encode(),stdout=subprocess.PIPE).stdout
if dst.exists(): raise SystemExit('Copy destination already exists; inspect before proceeding')
if sql('SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME="wp-only1-multi-php85-integration";').strip(): raise SystemExit('Clone DB exists; refusing overwrite')

engines=sql('SELECT DISTINCT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA="wp-only1-multi" AND TABLE_TYPE="BASE TABLE";').decode().splitlines()
if engines != ['InnoDB']: raise SystemExit('Inspect non-InnoDB tables before copying')
base=sql('SELECT TABLE_NAME,ENGINE,TABLE_COLLATION FROM information_schema.TABLES WHERE TABLE_SCHEMA="wp-only1-multi" ORDER BY TABLE_NAME;')
(tmp/'source-schema.tsv').write_bytes(base)
run(['rsync','-a','--exclude=.git','--exclude=node_modules','--exclude=wp-content/cache','--exclude=wp-content/upgrade','--exclude=wp-content/updraft','--exclude=wp-content/ai1wm-backups',str(src)+'/',str(dst)+'/'])
with (tmp/'wordpress.sql').open('wb') as f:
 run(['docker','exec','local-db','sh','-c','MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb-dump -uroot --single-transaction --skip-lock-tables --hex-blob wp-only1-multi'],stdout=f)
pw=secrets.token_hex(24)
sql("CREATE DATABASE `wp-only1-multi-php85-integration` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci; CREATE USER 'wp80_integration'@'%' IDENTIFIED BY '"+pw+"'; GRANT ALL PRIVILEGES ON `wp-only1-multi-php85-integration`.* TO 'wp80_integration'@'%';")
with (tmp/'wordpress.sql').open('rb') as f:
 run(['docker','exec','-i','local-db','sh','-c','MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot wp-only1-multi-php85-integration'],stdin=f)
p=dst/'wp-config.php'; text=p.read_text()
for key,value in [('DB_NAME','wp-only1-multi-php85-integration'),('DB_USER','wp80_integration'),('DB_PASSWORD',pw),('DB_HOST','local-db')]:
 text,n=re.subn(r"define\(\s*['\"]"+key+r"['\"]\s*,\s*['\"][^'\"]*['\"]\s*\);", "define( '"+key+"', '"+value+"' );",text)
 if n!=1: raise SystemExit('Unexpected config field '+key)
text=text.replace("require_once ABSPATH . 'wp-settings.php';", "// Isolated PHP85 integration copy; never schedule background work or contact external hosts.\ndefine('DISABLE_WP_CRON', true);\ndefine('AUTOMATIC_UPDATER_DISABLED', true);\ndefine('DISALLOW_FILE_MODS', true);\ndefine('WP_HTTP_BLOCK_EXTERNAL', true);\ndefine('WP_ACCESSIBLE_HOSTS', 'localhost-gbc-pilot,localhost-wp-only1-multi');\nrequire_once ABSPATH . 'wp-settings.php';")
p.write_text(text);p.chmod(0o600)
(dst/'wp-content/mu-plugins').mkdir(exist_ok=True)
(dst/'wp-content/mu-plugins/000-integration-isolation.php').touch()
(tmp/'prepared.json').write_text(json.dumps({'source':str(src),'copy':str(dst),'db':'wp-only1-multi-php85-integration','tables':len(base.decode().splitlines()),'dump_sha256':hashlib.sha256((tmp/'wordpress.sql').read_bytes()).hexdigest()},indent=2))
print('WordPress copied and DB cloned. Configure the target site with configure.php, verify isolation, then create .integration-ready.')
