import 'package:flutter/material.dart';
import 'student_register_screen.dart';
import 'teacher_register_screen.dart';

class UserSelectionScreen extends StatelessWidget {
  const UserSelectionScreen({super.key});


  void navigateToTeacherRegister(BuildContext context) {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeacherRegistrationScreen(),
      ),
    );

  }


  void navigateToStudentRegister(BuildContext context) {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StudentRegistrationScreen(),
      ),
    );

  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.grey.shade100,


      appBar: AppBar(

        title: const Text(
          'Who are you?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        centerTitle: true,

        backgroundColor: Colors.deepPurple,

        foregroundColor: Colors.white,

      ),


      body: SafeArea(

        child: SingleChildScrollView(

          child: Padding(

            padding: const EdgeInsets.symmetric(
              vertical: 30,
              horizontal: 20,
            ),


            child: Column(

              crossAxisAlignment: CrossAxisAlignment.center,


              children: [


                const Text(

                  'Are you a...',

                  style: TextStyle(

                    fontSize: 26,

                    fontWeight: FontWeight.bold,

                  ),

                ),



                const SizedBox(height: 35),



                // Teacher Section

                Image.asset(

                  'assets/images/teacher.png',

                  height: 150,

                ),


                const SizedBox(height: 15),



                SizedBox(

                  width: double.infinity,


                  child: ElevatedButton.icon(

                    onPressed: () =>
                        navigateToTeacherRegister(context),


                    icon: const Icon(
                      Icons.school,
                      size: 28,
                    ),


                    label: const Text(

                      'Teacher',

                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),

                    ),


                    style: ElevatedButton.styleFrom(

                      backgroundColor: Colors.deepPurple,

                      foregroundColor: Colors.white,


                      minimumSize: const Size(
                        double.infinity,
                        55,
                      ),


                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(12),

                      ),

                    ),

                  ),

                ),




                const SizedBox(height: 45),




                // Student Section

                Image.asset(

                  'assets/images/student.png',

                  height: 150,

                ),



                const SizedBox(height: 15),



                SizedBox(

                  width: double.infinity,


                  child: ElevatedButton.icon(

                    onPressed: () =>
                        navigateToStudentRegister(context),


                    icon: const Icon(

                      Icons.person,

                      size: 28,

                    ),



                    label: const Text(

                      'Student',

                      style: TextStyle(

                        fontSize: 20,

                        fontWeight: FontWeight.bold,

                      ),

                    ),



                    style: ElevatedButton.styleFrom(

                      backgroundColor: Colors.teal,

                      foregroundColor: Colors.white,


                      minimumSize: const Size(
                        double.infinity,
                        55,
                      ),


                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(12),

                      ),

                    ),

                  ),

                ),


              ],

            ),

          ),

        ),

      ),

    );

  }

}