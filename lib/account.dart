import 'dart:convert';

import 'package:flutter/material.dart';

import 'data-structure.dart';
import 'network_handler.dart';
import 'ui-core.dart';

class LoginWidget extends StatelessWidget {
  const LoginWidget({
    super.key,
    required this.loginServer,
    required this.data,
    required this.parseSuccessfulLoginResponse,
  });

  final NetworkConnection loginServer;
  final DataStructure data;
  final void Function(List<String> message) parseSuccessfulLoginResponse;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      OutlinedButton(
        onPressed: () {
          loginServer.send(['new']).then((List<String> message) {
            if (message[0] == 'T') {
              data.setCredentials(message[1], message[2]);
              List<String> loginResponse = message.skip(2).toList();
              loginResponse[0] = 'T';
              parseSuccessfulLoginResponse(loginResponse);
              assert(message.length == 5);
            } else {
              assert(message[0] == 'F');
              assert(message.length == 2);
              openErrorDialog(
                'Error when creating new account: ${message[1]}',
                context,
              );
            }
          });
        },
        child: Text('Start new game'),
      ),
      SizedBox(
        height: 10,
      ),
      OutlinedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => LoginDialog(
              data: data,
              connection: loginServer,
              parseSuccessfulLoginResponse: parseSuccessfulLoginResponse,
            ),
          );
        },
        child: Text('Login'),
      ),
    ]);
  }
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({
    super.key,
    required this.data,
    required this.connection,
    required this.parseSuccessfulLoginResponse,
  });

  final DataStructure data;
  final NetworkConnection connection;
  final void Function(List<String> message) parseSuccessfulLoginResponse;

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  TextEditingController username = TextEditingController();
  TextEditingController password = TextEditingController();
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Login'),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Username:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: username,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Password:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: password,
                    obscureText: true,
                  ),
                ),
              ],
            ),
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                if (username.text.contains('\x00')) {
                  errorMessage = 'Username must not contain 0x0 byte.';
                  return;
                }
                if (password.text.contains('\x00')) {
                  errorMessage = 'Password must not contain 0x0 byte.';
                  return;
                }
                widget.connection
                    .send(['login', username.text, password.text]).then(
                        (List<String> message) {
                  if (message[0] == 'F') {
                    if (message[1] == 'unrecognized credentials') {
                      setState(() {
                        errorMessage = 'Username or password incorrect.';
                      });
                    } else {
                      if (mounted) {
                        Navigator.pop(context);
                        openErrorDialog(
                          'Error logging in: ${message[1]}',
                          context,
                        );
                      }
                    }
                  } else {
                    assert(message[0] == 'T');
                    try {
                      widget.data.setCredentials(username.text, password.text);
                      widget.parseSuccessfulLoginResponse(message);
                    } finally {
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    }
                  }
                });
              },
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountWidget extends StatelessWidget {
  const AccountWidget({
    super.key,
    required this.data,
    required this.loginServer,
    required this.logout,
    required this.isDarkMode,
  });

  final DataStructure data;
  final NetworkConnection loginServer;
  final VoidCallback logout;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: data,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Logged in as ${data.username}'),
              SizedBox(
                height: 10,
              ),
              OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => TextFieldDialog(
                      obscureText: false,
                      onSubmit: (String newUsername) {
                        if (newUsername.contains('\x00')) {
                          return Future.value(
                            'Username must not contain 0x0 byte.',
                          );
                        }
                        return loginServer.send(
                          [
                            'change-username',
                            data.username!,
                            data.password!,
                            newUsername,
                          ],
                        ).then(
                          (List<String> message) {
                            if (message[0] == 'F') {
                              assert(message.length == 2);
                              if (message[1] == 'unrecognized credentials') {
                                logout();
                                openErrorDialog(
                                  'You have changed your username or password on another device.\nPlease log in again with your new username and password.',
                                  context,
                                );
                                Navigator.pop(context);
                              } else if (message[1] == 'inadequate username') {
                                if (newUsername == '') {
                                  return 'Username must be non-empty.';
                                } else if (newUsername.contains('\x10')) {
                                  return 'Username must not contain 0x10 byte.';
                                } else {
                                  return 'Username already in use.';
                                }
                              } else {
                                openErrorDialog(
                                  'Error when changing username: ${message[1]}',
                                  context,
                                );
                                Navigator.pop(context);
                              }
                            } else {
                              assert(message[0] == 'T');
                              data.updateUsername(newUsername);
                              assert(message.length == 1);
                              Navigator.pop(context);
                            }
                            return null;
                          },
                        );
                      },
                      dialogTitle: 'Change username',
                      buttonMessage: 'Change username',
                      textFieldLabel: 'New username',
                    ),
                  );
                },
                child: Text('Change username'),
              ),
              SizedBox(
                height: 10,
              ),
              OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => TextFieldDialog(
                      obscureText: true,
                      onSubmit: (String newPassword) {
                        if (newPassword.contains('\x00')) {
                          return Future.value(
                            'Password must not contain 0x0 byte.',
                          );
                        }
                        return loginServer.send([
                          'change-password',
                          data.username!,
                          data.password!,
                          newPassword,
                        ]).then(
                          (List<String> message) {
                            if (message[0] == 'F') {
                              assert(message.length == 2);
                              if (message[1] == 'unrecognized credentials') {
                                logout();
                                openErrorDialog(
                                  'You have changed your username or password on another device.\nPlease log in again with your new username and password.',
                                  context,
                                );
                                Navigator.pop(context);
                              } else if (message[1] == 'inadequate password') {
                                assert(utf8.encode(newPassword).length < 6);
                                return 'Password must be at least 6 characters long.';
                              } else {
                                openErrorDialog(
                                  'Error when changing password: ${message[1]}',
                                  context,
                                );
                                Navigator.pop(context);
                              }
                            } else {
                              assert(message[0] == 'T');
                              data.updatePassword(newPassword);
                              assert(message.length == 1);
                              Navigator.pop(context);
                            }
                            return null;
                          },
                        );
                      },
                      dialogTitle: 'Change password',
                      buttonMessage: 'Change password',
                      textFieldLabel: 'New password',
                    ),
                  );
                },
                child: Text('Change password'),
              ),
              SizedBox(
                height: 10,
              ),
              OutlinedButton(
                onPressed: () {
                  loginServer.send([
                    'logout',
                    data.username!,
                    data.password!,
                  ]).then((List<String> message) {
                    if (message[0] == 'F') {
                      if (message[1] == 'unrecognized credentials') {
                        // (we're logging out, we don't care about unrecognized credentials)
                        logout();
                        Navigator.pop(context);
                      } else {
                        openErrorDialog(
                          'Error when logging out: ${message[1]}',
                          context,
                        );
                      }
                    } else {
                      assert(message[0] == 'T');
                      assert(message.length == 1);
                      if (data.username != null && data.password != null) {
                        logout();
                        Navigator.pop(context);
                      }
                    }
                  });
                },
                child: Text('Logout'),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [Text('Get icons from network'), CookieCheckbox(cookie: 'networkImages')],)
            ],
          );
        });
  }
}
