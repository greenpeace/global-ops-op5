#!/bin/sh
host=""
route_a=""
route_b=""
# Exit status if secondary route is in use
secondary_exit=1
timeout=30
while [ "$1" != "" ]; do
  if [ "$1" = "-H" -o "$1" = "--host" ]; then shift; host="$1"
  elif [ "$1" = "-P" -o "$1" = "--primary" ]; then shift; route_a="$1"
  elif [ "$1" = "-S" -o "$1" = "--secondary" ]; then shift; route_b="$1"
  elif [ "$1" = "-T" -o "$1" = "--timeout" ]; then shift; timeout="$1"
  elif [ "$1" = "-C" -o "$1" = "--critifsec" ]; then shift; secondary_exit=2
  elif [ "$1" = "-h" -o "$1" = "--help" ]; then
    echo "Usage: $0 -H <host> -P <primary route> [-S <secondary route>] [-T <seconds>]"
    echo "-H, --host        Which host to trace the route to"
    echo "-P, --primary     Which route should be the primary alternative"
    echo "-S, --secondary   Which route should be the secondary alternative"
    echo "-C, --critifsec   Exit with critical state if secondary route is in use (warning is default)"
    echo "-T, --timeout     How long to wait before giving up (in seconds)"
    echo "-h, --help        Print this help"
    exit 0
  else
    echo "Unknown argument '$1', type $0 --help to see the correct usage"
    exit 3
  fi
  shift
done
if [ "$host" = "" ]; then echo "Missing host"; exit 3; fi
if [ "$route_a" = "" ]; then echo "Missing primary route"; exit 3; fi
hostpid=$$
traceroute "$host" | sed -e "1d;s/.*(\(.*\)).*/\1/" > /tmp/check_route.$$ &
time=0
unreachable=no
while [ "`jobs | grep -i Running`" != "" ]; do
  if [ "$timeout" != "" -a "$time" -gt "$timeout" ]; then
    kill %1
    unreachable=yes
  fi
  sleep 1
  let time=$time+1
done

routes="`cat /tmp/check_route.$$ | sort`"
unsortedroutes="`cat /tmp/check_route.$$`"
rm /tmp/check_route.$$
prevroute=none
for x in $routes; do
  if [ "$prevroute" = "$x" ]; then
    echo -n "CRITICAL: Loop in route: "
    foundend=false
    for y in $unsortedroutes; do
      if $foundend; then
        if [ "$x" = "$y" ]; then echo -n "$y"; break; fi
        echo -n "$y, "
      else
        if [ "$x" = "$y" ]; then echo -n "$y, "; foundend=true; fi
      fi
    done
    exit 2
  fi
  prevroute="$x"
done
if [ "$unreachable" = "yes" ]; then
  echo "CRITICAL: Target not reachable"
  rm /tmp/check_route.$$
  exit 2
fi
if [ "$route_b" != "" ] && echo "$routes" | grep "$route_b" > /dev/null; then
  if [ $secondary_exit = 2 ]; then
    echo "CRITICAL: Went through secondary route $route_b"
    exit 2
  else
    echo "WARNING: Went through secondary route $route_b"
    exit 1
  fi
fi
if [ "`echo "$routes" | grep "$route_a"`" = "" ]; then
  echo "CRITICAL: Went through unknown route (neither primary nor secondary)"
echo "$routes"
  exit 1
fi
echo "OK: `echo "$routes" | wc -l` hops to reach $host through $route_a"
exit 0
