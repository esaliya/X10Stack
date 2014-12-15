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

/**
 * The classic hello world program, with a twist - lists each place
 * Converted to 2.1 9/1/2010
 */
class SimpleAtomic {
  public static def main(Array[String]):void {
     finish for (p in Place.places()) {
     	async at (p) Console.OUT.println("Hello World from place "+p.id);
     }

     var me : Place = here;
     var other : Place  = here.next();
     /*val cell = new Cell[Int](0);
     finish {
     	async atomic cell.set(cell()+ 1);
	async at (other) atomic cell.set(cell()+ 2);// Argh! I forgot about deep copying with X10 at. So this line as has no effect on the original cell.
     }
     Console.OUT.println("Place: " + here + " cell: " + cell());*/

     val blk = Dist.makeBlock((1..1)*(1..1),0);
     val data = DistArray.make[Int](blk, ([i,j]:Point(2)) => 0);
     /*for (pt in data){
        at (blk(pt)) Console.OUT.println("D(pt): " + blk(pt) + " pt: " + pt + " val: " + data(pt));
     }*/
     val pt : Point = [1,1];
     finish for (pl in Place.places()) {
        async{
	   val dataloc = blk(pt);
	   if (dataloc != pl){
              Console.OUT.println("Point " + pt + " is not in place " + pl +" ,but in place " + dataloc);
	      at (dataloc) atomic {
	         data(pt) = data(pt) + 1;
	      }
	   }
	   else {
              Console.OUT.println("Point " + pt + " is in place " + pl);
	      atomic data(pt) = data(pt) + 2;
	   }
	}
     }
     Console.OUT.println("Final value of point " + pt + " is " + data(pt));
  }
}


