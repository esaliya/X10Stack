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
class LocalHandlerTest {
	static val SIZE = 8;
	public static def main(Array[String]):void {
		val local_arr = PlaceLocalHandle.make[Array[Float](1)](PlaceGroup.WORLD, () =>  new Array[Float](SIZE));
		val usual_arr = new Array[Float](SIZE);
		val temp_arr = new Array[Float](SIZE);
		// val cell = GlobalRef(new Cell[Int](132));
		val local_butsame_arr = PlaceLocalHandle.make[Array[Float](1)](PlaceGroup.WORLD, () =>  temp_arr);
		// val local_butsame_cell = PlaceLocalHandle.make[Cell[Int]](PlaceGroup.WORLD, () =>  cell());
		
		// val t = local_butsame_cell();
		// at (here.next()){
			// Console.OUT.println(local_butsame_cell() == t);
			// Console.OUT.println(local_butsame_cell()() == t());
		// }
		
		
		// for (var j:Int=0 ; j<SIZE ; ++j) {
		// 	// local_butsame_arr()(j) = 11+j;
		// 	temp_arr(j) = 11+j;
		// }
		
		finish for (p in Place.places()) {
			async at (p) {
				for (var j:Int=0 ; j<SIZE ; ++j) {
					// This is local to the place. 
					// We've created a separate array at each place <-- what I am no sure is how to map to same object. Even in local_butsame_arr the mapped objecs are still different
					// So they get initilize separately.
					// It seems at shifting has not copied the actual array mapped by local_arr. Not sure how it happens.
					local_arr()(j) = j;
					// This effect is not visible once you return from this place. 
					// Remeber X10 will do a deep copy of usual_arr to each place (even to the same place). 
					// So p.id+111 is done for tha copied array.
					usual_arr(j) = p.id+111; 
				}
			}
		}
		
		finish for (p in Place.places()) {
			async at (p) {
				// Console.OUT.println("Hello World from place "+p.id);
				for (var j:Int=0 ; j<SIZE ; ++j) {
					Console.OUT.println("local_arr - " + p.id + " - " +local_arr()(j));
					// Console.OUT.println("local_butsame_arr - " + p.id + " - " +local_butsame_arr()(j));
					Console.OUT.println("usual_arr - " + p.id + " - " +usual_arr(j));
				}
			}
		}
	}
}


