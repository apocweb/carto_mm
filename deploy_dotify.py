#!/usr/bin/python

import csv
import sys

if len(sys.argv) != 4:
	print "Pas assez d'argument"
	sys.exit(1)

f_app = open(sys.argv[1], 'rb')
f_cluster = open(sys.argv[2], 'rb')
fo = open(sys.argv[3], 'wb')

servers = {}
reader = csv.DictReader(f_app)
for row in reader:
	h = row['hostname']
	i = row['instance']
	a = row['application']
	x = row['xmx']
	if not h in servers:
		servers[h] = {}
		servers[h][i] = [a]
	elif not i in servers[h]:
		servers[h][i] = [a]
	else:
		servers[h][i].append(a)
f_app.close()

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

fo.write('graph g {\n')
for cluster in clusters:
	fo.write('\tsubgraph "cluster-' + cluster + '" {\n')
	fo.write('\t\tlabel="{}"\n'.format(cluster))
	for host in clusters[cluster]:
		fo.write('\t\tsubgraph "cluster-' + host + '" {\n')
		fo.write('\t\t\tlabel="{}"\n'.format(host))
		for tomcat in clusters[cluster][host]:
			#fo.write('\t\t\tsubgraph "cluster-' + tomcat + '" {\n')
			#fo.write('\t\t\t\tlabel="{}"\n'.format(tomcat))
			fo.write('\t\t\t"{}-{}" [shape=box,color=lightgrey,style=filled,label="{}"]\n'.format(host,tomcat,tomcat))
			for application in clusters[cluster][host][tomcat]:
				if application != '':
					fo.write('\t\t\t\t"{}-{}-{}" [label="{}"]\n'.format(host,tomcat,application,application))
					fo.write('\t\t\t\t"{}-{}"--"{}-{}-{}"\n'.format(host,tomcat,host,tomcat,application))
			#fo.write('\t\t\t}\n')
		fo.write('\t\t}\n')
	fo.write('\t}\n')
fo.write('}\n')
fo.close()
