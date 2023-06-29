import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:fritter/constants.dart';
import 'package:fritter/database/entities.dart';
import 'package:fritter/BrowsingTweets/_tweets.dart';
import 'package:fritter/profile/profile.dart';
import 'package:fritter/subscriptions/users_model.dart';
import 'package:fritter/ui/errors.dart';
import 'package:fritter/user.dart';
import 'package:provider/provider.dart';
import 'package:fritter/generated/l10n.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:fritter/constants.dart';
import 'package:fritter/database/entities.dart';
import 'package:fritter/generated/l10n.dart';
import 'package:fritter/profile/_follows.dart';
import 'package:fritter/profile/_saved.dart';
import 'package:fritter/profile/_tweets.dart';
import 'package:fritter/profile/profile_model.dart';
import 'package:fritter/ui/errors.dart';
import 'package:fritter/ui/physics.dart';
import 'package:fritter/user.dart';
import 'package:fritter/utils/urls.dart';
import 'package:intl/intl.dart';
import 'package:measure_size/measure_size.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

class BrowsingTweets extends StatefulWidget {
  const BrowsingTweets({Key? key}) : super(key: key);

  @override
  State<BrowsingTweets> createState() => _BrowsingTweetsState();
}

class _BrowsingTweetsState extends State<BrowsingTweets> {
  @override
  Widget build(BuildContext context) {
    var model = context.read<SubscriptionsModel>();
    return ScopedBuilder<SubscriptionsModel, Object, List<Subscription>>.transition(
      store: model,
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onError: (_, e) => FullPageErrorWidget(error: e, stackTrace: null, prefix: L10n.of(context).unable_to_refresh_the_subscriptions),
      onState: (_, state) {
        if (state.isEmpty) {
          return Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: const Text('¯\\_(ツ)_/¯', style: TextStyle(fontSize: 32)),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(L10n.of(context).no_subscriptions_try_searching_or_importing_some,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                        )),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ElevatedButton(
                      child: Text(L10n.of(context).import_from_twitter),
                      onPressed: () => Navigator.pushNamed(context, routeSubscriptionsImport),
                    ),
                  )
                ]));
        }

        return ProfileScreen(subscription:state);
      },
    );
  }
}
class ProfileScreen extends StatelessWidget {
  final List<Subscription>? subscription;
  const ProfileScreen({Key? key,required this.subscription}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return Provider(
        create: (context) {
          if (id != null) {
            return ProfileModel()..loadProfileById(id!);
          } else {
            return ProfileModel()..loadProfileByScreenName(screenName!);
          }
        },
        child: _ProfileScreen(id: id, screenName: screenName)
    );
  }
}
class _ProfileScreen extends StatelessWidget {
  final String? id;
  final String? screenName;

  const _ProfileScreen({Key? key, required this.id, required this.screenName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScopedBuilder<ProfileModel, Object, Profile>.transition(
        store: context.read<ProfileModel>(),
        onError: (_, error) => FullPageErrorWidget(
          error: error,
          stackTrace: null,
          prefix: L10n.of(context).unable_to_load_the_profile,
          onRetry: () {
            if (id != null) {
              return context.read<ProfileModel>().loadProfileById(id!);
            } else {
              return context.read<ProfileModel>().loadProfileByScreenName(screenName!);
            }
          },
        ),
        onLoading: (_) => const Center(child: CircularProgressIndicator()),
        onState: (_, state) => ProfileScreenBody(profile: state),
      ),
    );
  }
}
class ProfileScreenBody extends StatefulWidget {
  final Profile profile;
  const ProfileScreenBody({Key? key, required this.profile}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ProfileScreenBodyState();
}

class _ProfileScreenBodyState extends State<ProfileScreenBody> with TickerProviderStateMixin {

  @override
  Widget build(BuildContext context) {
    var prefs = PrefService.of(context, listen: false);
    var user = widget.profile.user;
    if (user.idStr == null) {
      return Container();
    }
    return Scaffold(
      body: MultiProvider(
          providers: [
            ChangeNotifierProvider<TweetContextState>(create: (_) => TweetContextState(prefs.get(optionTweetsHideSensitive)))
          ],
        child: ProfilesTweets(
            user: user, type: 'profile', includeReplies: false, pinnedTweets: widget.profile.pinnedTweets),
      ),
    );
  }
}
