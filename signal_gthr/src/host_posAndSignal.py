#!/usr/bin/env python
## Signal_strength that publishes std_msgs/String messages about the 
## dBm (deciBels per milliwat, a common measure of wifi signal strength)
## at a constant rate to the 'signal_strength' topic.
import time
import rospy
from std_msgs.msg import String
from geometry_msgs.msg import Point ##add to dependencies
from std_msgs.msg import Int64
import sys
import subprocess

##change these
interface = "wlan0"
network = "" #add your network here

#global vars
pos = [0,0]
strength = 0
pub = rospy.Publisher('signal_dtagthr', String, queue_size=10)

def collectSignalData():
    rospy.init_node('signal_strength_dtagthr', anonymous=True)
    rospy.Subscriber("/odom/pose/pose/position", Point, call_odom)
    rospy.Subscriber("signal_strength", Int64, call_signal)
    rospy.spin()

def call_odom(curCoords):
    pos = curCoords[:3] #potentially convert to [], cuts z
	#potentially parse later on
    return "done update coords"

def call_signal(curStrength):
    strength = str(curStrength).split(' ')[1]
    
    output = str(pos[0]) + "," + str(pos[0]) + "," + str(strength)
    rospy.loginfo("Publishing New Data: " +str(output))
    
    rospy.loginfo(output)
    
    if not rospy.is_shutdown():
        pub.publish(output)
        
    return "done update strength"
    
if __name__ == '__main__':
    try:
        collectSignalData()
    except rospy.ROSInterruptException:
        pass
