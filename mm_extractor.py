#!/usr/bin/python

import sys
import getopt

from xml.sax import make_parser
from xml.sax.handler import ContentHandler

"""
Extracting Tomcat process information
hostname, PID, jvmRoute (SFR specific param for http routing), Xms, Xmx, High Water Mark, uptime
"""
class TomcatProcessHandler(ContentHandler):

	def __init__ (self):
		self.hostname = ""
		self.process = ""
		self.xms = ""
		self.xmx = ""
		self.hwm = ""
		self.pid = ""
		self.uptime = ""
		self.PID = ""
		self.hostnames = []
		self.processes = []

	"""
	Parsing mm file
	"""
	def startElement(self, name, attrs):
		if name == 'node':			
			try:
				if attrs.has_key('hostname') and attrs.has_key('TEXT'):
					self.hostname = attrs.getValue('TEXT')
					self.hostnames.append(self.hostname)
				elif attrs.has_key('tomcatProcess') and attrs.has_key('TEXT'):
					self.process = attrs.getValue('TEXT')
					self.xms = self.xmx = self.hwm = self.pid = ""
				elif attrs.has_key('xms') and attrs.has_key('TEXT'):
                                       	self.xms = attrs.getValue('TEXT')
				elif attrs.has_key('xmx') and attrs.has_key('TEXT'):
					self.xmx = attrs.getValue('TEXT')
				elif attrs.has_key('VmHWM') and attrs.has_key('TEXT'):
					self.hwm = attrs.getValue('TEXT')
				elif attrs.has_key('tomcatUptime') and attrs.has_key('TEXT'):
					self.uptime = attrs.getValue('TEXT')
				elif attrs.has_key('tomcatProcessPID') and attrs.has_key('TEXT'):
					self.PID = attrs.has_key('TEXT')
                                        self.processes.append((self.hostname, self.process, self.xms, self.xmx, self.hwm, self.uptime, self.PID))
			except:
				print attrs
				print sys.exc_info()[0]
				
	"""
	Extracting into CSV file
	"""
	def csvRenderer(self, filename = "tomcat_process.csv"):
		f = open(filename, 'w')
                f.write('"hostname","instances","Xms","Xmx","HWN","uptime"\n')
		for h, i, xms, xmx, hwm, uptime, pid in self.processes:
			f.write('"{0}","{1}","{2}","{3}","{4}","{5}","{6}"\n'.format(h, i, xms, xmx, hwm, uptime, pid))
		f.close()
		
"""
Extracting Tomcat instance configuration
hostname, install, instances, PID
"""
class TomcatHandler(ContentHandler):

	def __init__ (self):
		self.hostname = ""
		self.instance = ""
		self.PID = ""
		self.hostnames = []
		self.instances = []
		self.catalinas = []

	def startElement(self, name, attrs):
		if name == 'node':			
			if attrs.has_key('hostname'):
				if attrs.has_key('TEXT'):
					self.hostname = attrs.getValue('TEXT')
					self.hostnames.append(self.hostname)
				else:
					sys.stderr.write('Attribut TEXT vide')
			elif attrs.has_key('tomcatinstance'):
				if attrs.has_key('TEXT'):
					self.instance = attrs.getValue('TEXT')
					self.PID = ""
				else:
					sys.stderr.write('Attribut TEXT vide')
			elif attrs.has_key('tomcatPID') and attrs.has_key('TEXT'):
				self.PID = attrs.getValue('TEXT')
			elif attrs.has_key('tomcatcatalina'):
			        if attrs.has_key('TEXT'):
                                        self.catalina = attrs.getValue('TEXT')
					self.instances.append((self.hostname, self.catalina, self.instance, self.PID))
					if self.catalinas.count((self.hostname, self.catalina)) == 0:
						self.catalinas.append((self.hostname, self.catalina))
                                else:
					sys.stderr.write('Attribut TEXT vide')
	
	def dotRenderer(self, filename = "tomcat.dot"):
		f = open(filename, 'w')
                f.write('digraph Tomcat {\n')
		#f.write('root=root\n')
		f.write('root [style=invisible];\n')
		#
		for h in self.hostnames:
			f.write('"{}" [shape=box, color=blue, style=filled];\n'.format(h))
		#
		for h, c in self.catalinas:
			f.write('"{}-{}" [label="{}", style=rounded, shape=box]\n'.format(h, c, c))
		#
		for h, c, i in self.instances:
			f.write('"{}-{}" [label="{}"]\n'.format(h, i, i))
		for h in self.hostnames:
			#f.write('root -> "' + h + '" [style=invisible]\n')
			pass
		#
		for h, c in self.catalinas:
			f.write('"{}" -> "{}-{}"\n'.format(h, h, c))
               	for h, c, i in self.instances:
			f.write('"{}-{}" -> "{}-{}"\n'.format(h, c, h, i))
       		f.write('}\n')
		f.close()
	
	def xmlRenderer(self, filename = "tomcat.mm"):
		sys.stderr.write('TomcatHandler.xmlRenderer() not yet implemented')
	
	def csvRenderer(self, filename = "tomcat.csv"):
		f = open(filename, 'w')
		f.write('"hostname","install","instances","PID"\n')
		for h, c, i, p in self.instances:
			f.write('"{}","{}","{}","{}"\n'.format(h, c, i, p))
		f.close()

"""
Extracting Tomcat instances with their application and status
status is :
 * Xmx value
 * -1 => Xmx indisponible
 * -2 => Tomcat instance not started (no PID found)
"""
class TomcatAppHandler(ContentHandler):
	def __init__(self):
		self.servers = []
		self.hostname = ""
		self.instance = ""
		self.apps = []
		self.processXmx = {}
		self.instanceXmx = {}

	def startElement(self, name, attrs):
		if name == 'node':
			if attrs.has_key('hostname') and attrs.has_key('TEXT'):
				self.hostname = attrs.getValue('TEXT')
				self.processXmx = {}
			elif attrs.has_key('xmx') and attrs.has_key('TEXT'):
				xmx = attrs.getValue('TEXT').lower()
				xmx = xmx.replace('k','000')
				xmx = xmx.replace('m','000000')
				xmx = xmx.replace('g','000000000')
				self.xmx = xmx
			elif attrs.has_key('tomcatProcessPID') and attrs.has_key('TEXT'):
				pid = attrs.getValue('TEXT')
				self.processXmx[pid] = self.xmx
			elif attrs.has_key('tomcatinstance') and attrs.has_key('TEXT'):
				self.instance = attrs.getValue('TEXT')
				self.apps = []
				self.servers.append((self.hostname, self.instance, self.apps))
			elif attrs.has_key('tomcatPID') and attrs.has_key('TEXT'):
				pid = attrs.getValue('TEXT')
				if pid in self.processXmx:
					self.instanceXmx[self.hostname + self.instance] = self.processXmx[pid]
				else:
					self.instanceXmx[self.hostname + self.instance] = -1
			elif attrs.has_key('deployWebApp') and attrs.has_key('TEXT'):
				self.apps.append(attrs.getValue('TEXT'))

	# xmx = -1 => Xmx indisponible
	# xmx = -2 => Pas de process identifie
	def csvRenderer(self, filename = "tomcatApp.csv"):
		f = open(filename, 'w')
		f.write('"hostname","instance","application","xmx"\n')
		for h, i, a in self.servers:
			key = h + i
			if key in self.instanceXmx:
				xmx = self.instanceXmx[key]
			else:
				xmx = -2
			if len(a) == 0:
				f.write('"{}","{}","",{}\n'.format(h, i, xmx))
			for app in a:
				f.write('"{}","{}","{}",{}\n'.format(h, i, app, xmx))
		f.close()

class ApplicationHandler(ContentHandler):
	def __init__ (self):
                self.hostname = ""
                self.applications = []

        def startElement(self, name, attrs):
                if name == 'node':
			if attrs.has_key('hostname'):
				if attrs.has_key('TEXT'):
					self.hostname = attrs.getValue('TEXT')
				else:
					sys.stderr.write('Attribut TEXT vide')
			elif attrs.has_key('application'):
				if attrs.has_key('TEXT'):
					self.applications.append((self.hostname, attrs.getValue('TEXT')))
				else:
					sys.stderr.write('Attribut TEXT vide')

	def csvRenderer(self, filename = "application.csv"):
		f = open(filename, 'w')
		f.write('"hostname","application"\n')
		for h, a in self.applications:
			f.write('"{}","{}"\n'.format(h, a))
		f.close()

class EtcHostsHandler(ContentHandler):

	def __init__ (self):
		self.hostname = ""
		self.etcHosts = ""
		self.etcHostsResolv = ""
		self.IPs = []
		self.hosts = []

	def __str__(self):
		return "EtcHostsHandler"

	def startElement(self, name, attrs):
		if name == 'node':
			if attrs.has_key('hostname'):
				if attrs.has_key('TEXT'):
					self.hostname = attrs.getValue('TEXT')
					self.IPs = []
				else:
					sys.stderr.write('Attribut TEXT vide')
			elif attrs.has_key('ip'):
                                if attrs.has_key('TEXT'):
                                        self.IPs.append(attrs.getValue('TEXT'))
                                else:   
                                        sys.stderr.write('Attribut TEXT vide')
			elif attrs.has_key('etcHosts'):
				if attrs.has_key('TEXT'):
					self.etcHosts = attrs.getValue('TEXT')
				else:   
				        sys.stderr.write('Attribut TEXT vide')
			elif attrs.has_key('etcHostsResolv'):
				if attrs.has_key('TEXT'):
					self.etcHostsResolv = attrs.getValue('TEXT')
					for ip in self.IPs:
						self.hosts.append((self.hostname, ip, self.etcHosts, self.etcHostsResolv))

	def dotRenderer(self, filename = "etchosts.dot"):
		f = open(filename, 'w')
		f.write('digraph etchosts {\n')
		for hostname, ipSource, ipTarget, resolv in self.hosts:
			if ipTarget != '127.0.0.1':
				f.write('"{}" -> "{}" [label="{}"]\n'.format(ipSource, ipTarget, resolv))
		f.write('}\n')
		f.close()

	def csvRenderer(self, filename = "etchosts.csv"):
		f = open(filename, 'w')
		f.write('"hostname","ip local","ip distante","host resolving"\n')
		for hostname, ipSource, ipTarget, resolv in self.hosts:
			f.write('"{0}","{1}","{2}","{3}"\n'.format(hostname, ipSource, ipTarget, resolv))
		f.close()
				
class NetworkHandler(ContentHandler):
	def __init__(self):
		self.hostname = ""
		self.interface = ""
		self.IP = ""
		self.subnet = ""
		self.MAC = ""
		self.network = []
		self.subnets = []
		self.hosts = []
		self.host = []

	def startElement(self, name, attrs):
		if name == 'node':
			if attrs.has_key('hostname'):
				if len(self.host) != 0:
					self.hosts.append((self.hostname, self.host))
					self.host = []
				if attrs.has_key('TEXT'):
					self.hostname = attrs.getValue('TEXT')
				else:
					sys.stderr.write('Attribut TEXT vide')
			elif attrs.has_key('interface'):
				if attrs.has_key('TEXT'):
					self.interface = attrs.getValue('TEXT')
                        elif attrs.has_key('ip'):
                                if attrs.has_key('TEXT'):
                                        self.IP = attrs.getValue('TEXT')
                        elif attrs.has_key('subnet'):
                                if attrs.has_key('TEXT'):
                                        self.subnet = attrs.getValue('TEXT')
					if self.subnets.count(self.subnet) == 0:
						self.subnets.append(self.subnet)
                        elif attrs.has_key('macaddr'):
                                if attrs.has_key('TEXT'):
                                        self.MAC = attrs.getValue('TEXT')
					self.host.append((self.subnet, self.IP, self.interface, self.MAC))
					self.network.append((self.subnet, self.IP, self.interface, self.MAC, self.hostname))

	def csvRenderer(self, filename = 'network.csv'):
		f = open(filename, 'w')
		f.write('"hostname","Interface","MAC","IP","Subnet"\n')
		for subnet, IP, interface, MAC, hostname in self.network:
			f.write('"{}","{}","{}","{}","{}"\n'.format(hostname, interface, MAC, IP, subnet))
		f.close()

	def dotRenderer(self, filename = 'network.dot'):
		f = open(filename, 'w')
		f.write('digraph g {\n')
		for sub in self.subnets:
			f.write('"{}" [shape=box]\n'.format(sub))
		for hostname, host in self.hosts:
			f.write('subgraph "cluster-' + hostname + '" {\n')
			f.write('style=filled\n')
			f.write('color=lightgrey\n')
			f.write('label="{}"\n'.format(hostname))	
			for subnet, IP, interface, MAC in host:
				f.write('"{}-{}" [label="{}"]\n'.format(hostname, interface, interface))
			f.write('}\n')
			for subnet, IP, interface, MAC in host:
				f.write('"{}-{}" -> "{}" [label="{}"]\n'.format(hostname, interface, subnet, IP))
		f.write('}\n')
		f.close()

	def dotRendererOld(self, filename = 'network.dot'):
		f = open(filename, 'w')
		f.write('digraph g {\n')
		for sub in self.subnets:
			f.write('"{}" [shape=box]\n'.format(sub))
		for subnet, IP, interface, MAC, hostname in self.network:
			f.write('"{}-{}" [label="{}"]\n'.format(hostname, interface, interface))
			f.write('"{}" -> "{}" -> "{}-{}" -> "{}"\n'.format(subnet, IP, hostname, interface, hostname))
		f.write('}')
		f.close()

class NFSHandler(ContentHandler):
	def __init__(self):
                self.hostname = ""
		self.currentLocalFS = ""
		self.currentRemoteFS = ""
		self.currentNFSServer = ""
		self.localFS = {}
		self.remoteFS = {}
		self.nfsMounting = []

        def startElement(self, name, attrs):
                if name == 'node':
                        if attrs.has_key('hostname'):
                                if attrs.has_key('TEXT'):
                                        self.hostname = attrs.getValue('TEXT')
					self.localFS[self.hostname] = []
			if attrs.has_key('nfsserver'):
				if attrs.has_key('TEXT'):
					self.currentNFSServer = attrs.getValue('TEXT')
					if not self.remoteFS.has_key(self.currentNFSServer):
						self.remoteFS[self.currentNFSServer] = []
			if attrs.has_key('remotefs'):
				if attrs.has_key('TEXT'):
					self.currentRemoteFS = attrs.getValue('TEXT')
					if self.remoteFS[self.currentNFSServer].count(self.currentRemoteFS) == 0:
						self.remoteFS[self.currentNFSServer].append(self.currentRemoteFS)
			if attrs.has_key('localfs'):
				if attrs.has_key('TEXT'):
					self.currentLocalFS = attrs.getValue('TEXT')
					self.nfsMounting.append((self.hostname, self.currentNFSServer, self.currentRemoteFS, self.currentLocalFS))
					if self.localFS[self.hostname].count(self.currentLocalFS) == 0:
						self.localFS[self.hostname].append(self.currentLocalFS)
					
	def csvRenderer(self, filename = 'NFS.csv'):
		f = open(filename, 'w')
		f.write('"hostname","NFS Server","local FS","remote FS"\n')
		for hostname, nfs, remoteFS, localFS in self.nfsMounting:
			f.write('"{}","{}","{}","{}"\n'.format(hostname, nfs, localFS, remoteFS))
		f.close()

	def dotRenderer(self, filename = 'NFS.dot'):
		f = open(filename, 'w')
		f.write('digraph g {\n')
		for hostname, l in self.localFS.iteritems():
			f.write('subgraph "cluster-' + hostname + '" {\n')
			f.write('style=filled\n')
			f.write('color=lightgrey\n')
			f.write('label="{}"\n'.format(hostname))
			for localfs in l:
				f.write('"{}-{}" [label="{}"]\n'.format(hostname, localfs, localfs))
			f.write('}\n')
		for server, l in self.remoteFS.iteritems():
			f.write('subgraph "cluster-' + server + '" {\n')
                        f.write('style=filled\n')
                        f.write('color=green\n')
                        f.write('label="NAS - {}"\n'.format(server))
			for remotefs in self.remoteFS[server]:
				f.write('"{}-{}" [label="{}"]\n'.format(server, remotefs, remotefs))
			f.write('}\n')
		for hostname, nfs, remoteFS, localFS in self.nfsMounting:
			f.write('"{}-{}" -> "{}-{}"\n'.format(hostname, localFS, nfs, remoteFS))
		f.write('}\n')
		f.close()	

class OSHandler(ContentHandler):
	pass

class ServerHandler(ContentHandler):

	def __init__(self):
		self.servers = []

	def startElement(self, name, attrs):
		if name == 'node':
			if attrs.has_key('hostname'):
				if attrs.has_key('TEXT'):
					self.servers.append(attrs.getValue('TEXT'))

	def csvRenderer(self, filename = 'servers.csv'):
		f = open(filename, 'w')
		f.write('"hostname","cluster"\n')
		for hostname in self.servers:
			f.write('"{0}",""\n'.format(hostname))
		f.close()

def usage(verbose=0):
	if verbose == 0:
		print "help ! :'("
	else:
		print "circo -Tpng tomcat.dot -o tomcat.png"

def main():
	try:
		opts, args = getopt.getopt(sys.argv[1:],
			"ui:o:f:r:",
			["usage", 
			"input=",
			"output=",
			"format=",
			"tomcat",
			"tomcatapp",
			"tomcatprocess",
			"etchosts",
			"network",
			"nfs",
			"appli",
			"server",
			"renderer="])
	except:
		usage()
		sys.exit(2)
	handler = None
	output_file = ""
	input_file = ""
	renderer = ""
	for o, a in opts:
		if o in ("-u", "--usage"):
			usage()
			sys.exit(0)
		elif o in ("-i", "--input"):
			input_file = a
		elif o in ("-o", "--output"):
			output_file = a
		elif o in ("-f", "--format"):
			outpout_format = a
		elif o in ("--renderer"):
			renderer = a
		elif o in ("--tomcatapp"):
			handler = TomcatAppHandler()
		elif o in ("--tomcat"):
			handler = TomcatHandler()
		elif o in ("--tomcatprocess"):
			handler = TomcatProcessHandler()
		elif o in ("--nfs"):
		 	handler = NFSHandler()
		elif o in ("--os"):
			handler = OSHandler()
		elif o in ("--network"):
			handler = NetworkHandler()
		elif o in ("--etchosts"):
			handler = EtcHostsHandler()
		elif o in ("--appli"):
			handler = ApplicationHandler()
		elif o in ("--server"):
			handler = ServerHandler()
		else:
			assert False, "unhandled option"
	if handler == None:
		sys.stderr.write('Aucun interpreteur XML choisi\n')
		sys.exit(2)
	if input_file == "":
		sys.stderr.write('Aucun fichier en input\n')
		sys.exit(2)
	parser = make_parser()   
	parser.setContentHandler(handler)
	parser.parse(open(input_file))
	if renderer == "":
		renderer = "csvRenderer"
		print 'No renderer specified. The default one is csvRenderer.'
	if not hasattr(handler, renderer):
		sys.stderr.write('Error : The renderer ' + renderer + ' does not exist for ')
	else:
		if output_file != "":
			getattr(handler, renderer)(output_file)
		else:
			getattr(handler, renderer)()

if __name__ ==  "__main__":
	main()
