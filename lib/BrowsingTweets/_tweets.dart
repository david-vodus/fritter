import 'package:flutter/material.dart';
import 'package:fritter/catcher/errors.dart';
import 'package:fritter/client.dart';
import 'package:fritter/database/entities.dart';
import 'package:fritter/profile/profile.dart';
import 'package:fritter/tweet/conversation.dart';
import 'package:fritter/ui/errors.dart';
import 'package:fritter/user.dart';
import 'package:fritter/utils/iterables.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:fritter/generated/l10n.dart';
import 'package:provider/provider.dart';

class ProfilesTweets extends StatefulWidget {
  final List<Subscription> profiles;
  final String type;
  final bool includeReplies;
  final List<String> pinnedTweets;

  const ProfilesTweets({Key? key, required this.profiles, required this.type, required this.includeReplies, required this.pinnedTweets})
      : super(key: key);

  @override
  State<ProfilesTweets> createState() => _ProfilesTweetsState();
}

class _ProfilesTweetsState extends State<ProfilesTweets> with AutomaticKeepAliveClientMixin<ProfilesTweets> {
  late PagingController<String?, TweetChain> _pagingController;

  static const int pageSize = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _pagingController = PagingController(firstPageKey: null);
    _pagingController.addPageRequestListener((cursor) {
      _loadTweets(cursor);
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future _loadTweets(String? cursor) async {
    try {
      List<TweetChain> chainALL=[];
      String? cursorBottom,cursorTop;
      // widget.profiles.asMap().entries.map((e) async
      // {
      //   var result = await Twitter.getTweets(e.value.id, widget.type, widget.pinnedTweets,
      //       cursor: cursor, count: pageSize, includeReplies: widget.includeReplies);
      //   chainALL.addAll(result.chains);
      //   if(e.key==0)
      //     cursorBottom=result.cursorBottom;
      //   if(e.key==widget.profiles.length-1)
      //     cursorTop=result.cursorTop;
      // });
      for (var profile in widget.profiles)
        {
          var result = await Twitter.getTweets(profile.id, widget.type, widget.pinnedTweets,
              cursor: cursor, count: pageSize, includeReplies: widget.includeReplies);
          chainALL.addAll(result.chains);
        }
      TweetStatus statusAll=TweetStatus(chains: chainALL, cursorBottom: cursorBottom, cursorTop: cursorTop);
      if (!mounted) {
        return;
      }

      if (statusAll.cursorBottom == _pagingController.nextPageKey) {
        _pagingController.appendLastPage([]);
      } else {
        _pagingController.appendPage(statusAll.chains, statusAll.cursorBottom);
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
      if (model.hideSensitive && (false ?? false)) {
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
              return TweetConversation(
                  id: chain.id, tweets: chain.tweets, username: widget.profiles.first.screenName!, isPinned: chain.isPinned);
            },
            firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: _pagingController.error[0],
              stackTrace: _pagingController.error[1],
              prefix: L10n.of(context).unable_to_load_the_tweets,
              onRetry: () => _loadTweets(_pagingController.firstPageKey),
            ),
            newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: _pagingController.error[0],
              stackTrace: _pagingController.error[1],
              prefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
              onRetry: () => _loadTweets(_pagingController.nextPageKey),
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
