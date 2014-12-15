/*
 *  This file is part of the X10 project (http://x10-lang.org).
 *
 *  This file is licensed to You under the Eclipse Public License (EPL);
 *  You may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *      http://www.opensource.org/licenses/eclipse-1.0.php
 *
 *  (C) Copyright IBM Corporation 2006-2010.
 */

import x10.io.Console;

class DArray {
  public static def main(Array[String]):void {

     var me : Place = here;
     var other : Place  = here.next();     
     val blk = Dist.makeBlock((1..4)*(1..4),0);
     val data = DistArray.make[Int](blk, ([i,j]:Point(2)) => i*j);

     for (pt in data){
/*	if (blk(pt) != me){
	   data(pt) = 1;
	}
	else {
	   data(pt) = 0;
	}*/
        at (blk(pt)) Console.OUT.println("D(pt): " + blk(pt) + " pt: " + pt + " val: " + data(pt));
     }
  }
}


