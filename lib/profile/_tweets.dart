import 'package:flutter/material.dart';
import 'package:fritter/catcher/errors.dart';
import 'package:fritter/client.dart';
import 'package:fritter/profile/profile.dart';
import 'package:fritter/tweet/conversation.dart';
import 'package:fritter/ui/errors.dart';
import 'package:fritter/user.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:fritter/generated/l10n.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

import 'filter_model.dart';

class ProfileTweets extends StatefulWidget {
  final UserWithExtra user;
  final String type;
  final bool includeReplies;
  final List<String> pinnedTweets;
  final BasePrefService pref;

  const ProfileTweets({Key? key, required this.user, required this.type, required this.includeReplies, required this.pinnedTweets, required this.pref})
      : super(key: key);

  @override
  State<ProfileTweets> createState() => _ProfileTweetsState();
}

class _ProfileTweetsState extends State<ProfileTweets> with AutomaticKeepAliveClientMixin<ProfileTweets> {
  late PagingController<String?, TweetChain> _pagingController;
  static const int pageSize = 20;
  int loadTweetsCounter = 0;
  late FilterModel filterModel;
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    filterModel= FilterModel(widget.user.idStr!,widget.pref);
    _pagingController = PagingController(firstPageKey: null);
    _pagingController.addPageRequestListener((cursor) {
      _loadTweets(cursor,filterModel);
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }
  void  incrementLoadTweetsCounter() {
    ++loadTweetsCounter;
  }
  int getLoadTweetsCounter(){
    return loadTweetsCounter;

  }
  Future _loadTweets(String? cursor, FilterModel filterModel) async {
    try {
      var result = await Twitter.getTweets(widget.user.idStr!, widget.type, widget.pinnedTweets,
          cursor: cursor, count: pageSize, includeReplies: widget.includeReplies,
          getTweetsCounter : getLoadTweetsCounter, incrementTweetsCounter: incrementLoadTweetsCounter,
          filterModel : filterModel);

      if (!mounted) {
        return;
      }

      if (result.cursorBottom == _pagingController.nextPageKey) {
        _pagingController.appendLastPage([]);
      } else {
        _pagingController.appendPage(result.chains, result.cursorBottom);
      }
    } catch (e, stackTrace) {
      Catcher.reportException(e, stackTrace);
      if (mounted) {
        _pagingController.error = [e, stackTrace];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<TweetContextState>(builder: (context, model, child) {
      if (model.hideSensitive && (widget.user.possiblySensitive ?? false)) {
        return EmojiErrorWidget(
          emoji: '🍆🙈🍆',
          message: L10n.current.possibly_sensitive,
          errorMessage: L10n.current.possibly_sensitive_profile,
          onRetry: () async => model.setHideSensitive(false),
          retryText: L10n.current.yes_please,
        );
      }

      return RefreshIndicator(
        onRefresh: () async => _pagingController.refresh(),
        child: PagedListView<String?, TweetChain>(
          padding: EdgeInsets.zero,
          pagingController: _pagingController,
          addAutomaticKeepAlives: false,
          builderDelegate: PagedChildBuilderDelegate(
            itemBuilder: (context, chain, index) {
              return TweetConversation(id: chain.id, tweets: chain.tweets,
                  username: widget.user.screenName!, isPinned: chain.isPinned);
            },
            firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: _pagingController.error[0],
              stackTrace: _pagingController.error[1],
              prefix: L10n.of(context).unable_to_load_the_tweets,
              onRetry: () => _loadTweets(_pagingController.firstPageKey,this.filterModel
              ),
            ),
            newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: _pagingController.error[0],
              stackTrace: _pagingController.error[1],
              prefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
              onRetry: () => _loadTweets(_pagingController.nextPageKey,this.filterModel),
            ),
            noItemsFoundIndicatorBuilder: (context) {
              return Center(
                child: Text(
                  L10n.of(context).could_not_find_any_tweets_by_this_user,
                ),
              );
            },
          ),
        ),
      );
    });
  }
}
