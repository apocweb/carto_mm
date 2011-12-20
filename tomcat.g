//gvpr file
//Applying dedicated layout on deploy_dotify.py result DOT file

//Default node style
N[type=="tomcatInstance"]{shappe="box"}
N[type=="app"]{style="rounded"}

//Tomcat instance color by Xmx
N[type=="tomcatInstance" && status=="noXmx"]{style="filled",color="plum"}
N[type=="tomcatInstance" && status=="lowXmx"]{style="filled",color="skyblue"}
N[type=="tomcatInstance" && status=="mediumXmx"]{style="filled",color="mediumseagreen"}
N[type=="tomcatInstance" && status=="highXmx"]{style="filled",color="gold"}
N[type=="tomcatInstance" && status=="veryHighXmx"]{style="filled",color="coral"}

//Tomcat instance and child node applications that are not started
N[type=="tomcatInstance" && status=="notStarted"]{style="filled,dashed",color="lightgrey"}
N[type=="app" && status=="notStarted"]{style="dashed,rounded"}
