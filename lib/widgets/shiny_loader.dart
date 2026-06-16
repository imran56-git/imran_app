import 'package:flutter/material.dart';

class CustomShinyLoading extends StatefulWidget {
  final Widget child;

    const CustomShinyLoading({Key? key, required this.child}) : super(key: key);

      @override
        State<CustomShinyLoading> createState() => _CustomShinyLoadingState();
        }

        class _CustomShinyLoadingState extends State<CustomShinyLoading>
            with SingleTickerProviderStateMixin {
              late AnimationController _controller;

                @override
                  void initState() {
                      super.initState();
                          _controller = AnimationController(
                                vsync: this,
                                      duration: const Duration(seconds: 2),
                                          )..repeat();
                                            }

                                              @override
                                                void dispose() {
                                                    _controller.dispose();
                                                        super.dispose();
                                                          }

                                                            @override
                                                              Widget build(BuildContext context) {
                                                                  return AnimatedBuilder(
                                                                        animation: _controller,
                                                                              builder: (context, child) {
                                                                                      return ShaderMask(
                                                                                                blendMode: BlendMode.srcIn,
                                                                                                          shaderCallback: (bounds) {
                                                                                                                      return LinearGradient(
                                                                                                                                    begin: Alignment.bottomCenter,
                                                                                                                                                  end: Alignment.topCenter,
                                                                                                                                                                transform: _SlidingGradientTransform(value: _controller.value),
                                                                                                                                                                              colors: const [
                                                                                                                                                                                              Color(0xFF8E8E93), 
                                                                                                                                                                                                              Colors.white,      
                                                                                                                                                                                                                              Color(0xFF8E8E93), 
                                                                                                                                                                                                                                            ],
                                                                                                                                                                                                                                                          stops: const [0.3, 0.5, 0.7],
                                                                                                                                                                                                                                                                      ).createShader(bounds);
                                                                                                                                                                                                                                                                                },
                                                                                                                                                                                                                                                                                          child: widget.child,
                                                                                                                                                                                                                                                                                                  );
                                                                                                                                                                                                                                                                                                        },
                                                                                                                                                                                                                                                                                                            );
                                                                                                                                                                                                                                                                                                              }
                                                                                                                                                                                                                                                                                                              }

                                                                                                                                                                                                                                                                                                              class _SlidingGradientTransform extends GradientTransform {
                                                                                                                                                                                                                                                                                                                final double value;
                                                                                                                                                                                                                                                                                                                  const _SlidingGradientTransform({required this.value});

                                                                                                                                                                                                                                                                                                                    @override
                                                                                                                                                                                                                                                                                                                      Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
                                                                                                                                                                                                                                                                                                                          final double shift = bounds.height * (1.5 * value - 0.5);
                                                                                                                                                                                                                                                                                                                              return Matrix4.translationValues(0.0, -shift, 0.0);
                                                                                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                                                                                