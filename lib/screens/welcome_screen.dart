import 'package:flutter/material.dart';
import '../main.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  void _navigateToNextScreen() {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Proceeding to next screen...'),
      ),
    );


    Future.delayed(const Duration(seconds: 1), () {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const FindYourBestTeacherTodayApp(),
        ),
      );

    });

  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(

        width: double.infinity,

        decoration: const BoxDecoration(

          gradient: LinearGradient(

            colors: [
              Color(0xFFE0F7FA),
              Color(0xFFFFFFFF),
            ],

            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,

          ),

        ),


        child: FadeTransition(

          opacity: _animation,


          child: SafeArea(

            child: Column(

              children: [


                const SizedBox(height: 90),



                const Text(

                  'Welcome',

                  style: TextStyle(

                    fontSize: 36,

                    fontWeight: FontWeight.bold,

                    color: Colors.deepPurple,

                    letterSpacing: 2,

                  ),

                ),



                const SizedBox(height: 45),




                const Padding(

                  padding: EdgeInsets.symmetric(horizontal: 20),

                  child: Text(

                    'Find Your Best Teacher Today',

                    textAlign: TextAlign.center,


                    style: TextStyle(

                      fontSize: 30,

                      fontWeight: FontWeight.bold,

                      color: Colors.deepPurpleAccent,

                      letterSpacing: 1.5,

                    ),

                  ),

                ),




                const SizedBox(height: 18),




                const Padding(

                  padding: EdgeInsets.symmetric(horizontal: 30),

                  child: Text(

                    "Don't wait for tomorrow — discover your best teacher today!",


                    textAlign: TextAlign.center,


                    style: TextStyle(

                      fontSize: 17,

                      fontStyle: FontStyle.italic,

                      color: Colors.black87,

                      height: 1.5,

                    ),

                  ),

                ),




                const Spacer(),




                SizedBox(

                  width: 280,

                  height: 60,


                  child: ElevatedButton(

                    onPressed: _navigateToNextScreen,


                    style: ElevatedButton.styleFrom(

                      backgroundColor: Colors.deepPurple,


                      elevation: 5,


                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(35),

                      ),

                    ),



                    child: const Text(

                      'Get Started',


                      style: TextStyle(

                        fontSize: 21,

                        fontWeight: FontWeight.bold,

                        color: Colors.white,

                      ),

                    ),


                  ),

                ),





                const SizedBox(height: 85),





                const Text(

                  'Created by Md Imran Mondal',


                  style: TextStyle(

                    fontSize: 15,

                    fontStyle: FontStyle.italic,

                    color: Colors.grey,

                  ),

                ),




                const SizedBox(height: 20),



              ],

            ),

          ),

        ),

      ),

    );

  }

}                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 