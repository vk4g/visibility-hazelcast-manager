 FROM hazelcast/management-center:3.12.4
 
 EXPOSE 8080
 
 # Start Management Center
CMD ["bash", "/opt/hazelcast/mancenter/start.sh"]
