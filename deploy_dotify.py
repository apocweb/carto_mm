#!/usr/bin/python

import csv
import sys

if len(sys.argv) != 4:
	print "Pas assez d'argument"
	sys.exit(1)

f_app = open(sys.argv[1], 'rb')
f_cluster = open(sys.argv[2], 'rb')
fo = open(sys.argv[3], 'wb')

## Getting applications by Tomcat and servers with their Xmx
servers = {}
reader = csv.DictReader(f_app)
for row in reader:
	h = row['hostname']
	i = row['instance']
	a = row['application']
	x = int(row['xmx'])
	if not h in servers:
		servers[h] = {}
		servers[h][i] = {}
		servers[h][i]['xmx'] = x
		servers[h][i]['application'] = [a]
	elif not i in servers[h]:
		servers[h][i] = {}
		servers[h][i]['xmx'] = x
		servers[h][i]['application'] = [a] 
	else:
		servers[h][i]['application'].append(a)
f_app.close()

## Grouping servers (with application and Tomcat) by cluster
clusters = {}
reader = csv.DictReader(f_cluster)
for row in reader:
	c = row['cluster']
	if c == '':
		c = 'Unknown'
	if not c in clusters:
		clusters[c]= {}
	h = row['hostname']
	if h in servers:
		clusters[c][h] = servers[h]
f_cluster.close()

## Creating DOT
fo.write('graph g {\n')
for cluster in clusters:
	## Writing "logical" clusters
	fo.write('\tsubgraph "cluster-' + cluster + '" {\n')
	fo.write('\t\tlabel="{}"\n'.format(cluster))

	## Putting servers into cluster
	for host in clusters[cluster]:
		fo.write('\t\tsubgraph "cluster-' + host + '" {\n')
		fo.write('\t\t\tlabel="{}"\n'.format(host))
		for tomcat in clusters[cluster][host]:

			## Selecting the Tomcat instance status from its Xmx value
			xmx = clusters[cluster][host][tomcat]['xmx']
			if xmx == -1:
				instanceStatus = 'noXmx'
			elif xmx == -2:
				instanceStatus = 'notStarted'
			else:
				xmx /= 1000000
			if xmx >= 0 and xmx <= 512:
				instanceStatus = 'lowXmx'
			elif xmx > 512 and xmx <= 1024:
                                instanceStatus = 'mediumXmx'
			elif xmx > 1024 and xmx <= 2048:
                                instanceStatus = 'highXmx'
			elif xmx > 2048:
                                instanceStatus = 'veryHighXmx'
			
			## Writting the Tomcat instances for the current server with their status
			fo.write('\t\t\t"{}-{}" [label="{}",type=tomcatInstance,status={}]\n'.format(host,tomcat,tomcat,instanceStatus))

			## Linking Tomcat instances with their applications
			for application in clusters[cluster][host][tomcat]['application']:
				if application != '':
					fo.write('\t\t\t\t"{}-{}-{}" [label="{}",type=app,status={}]\n'.format(host,tomcat,application,application,instanceStatus))
					fo.write('\t\t\t\t"{}-{}"--"{}-{}-{}"\n'.format(host,tomcat,host,tomcat,application))
		fo.write('\t\t}\n')
	fo.write('\t}\n')
fo.write('}\n')
fo.close()
