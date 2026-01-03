from pathlib import Path
text=Path('lib/pages/timeline_page.dart').read_text()
start=text.find("task.isImportant ?")
text_start=text.rfind('Text(',0,start)
end=text.find('const SizedBox(height: 2),', start)
block=text[text_start:end+len('const SizedBox(height: 2),')]
new_block="""if (task.isImportant)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: isCompact ? 24 : 28,
                            height: isCompact ? 24 : 28,
                            child: Lottie.asset('assets/lottie/Alert.json', repeat: true, animate: true, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.flag, size: isCompact ? 18 : 20, color: theme.colorScheme.error)),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              task.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    const SizedBox(height: 2),"""
text=text.replace(block,new_block)
Path('lib/pages/timeline_page.dart').write_text(text)
