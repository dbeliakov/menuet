#import <Cocoa/Cocoa.h>

#import "alert.h"
#import "EditableNSTextField.h"

void alertClicked(int, const char *);

void showAlert(const char *jsonString) {
	NSDictionary *jsonDict = [NSJSONSerialization
	                          JSONObjectWithData:[[NSString stringWithUTF8String:jsonString]
	                                              dataUsingEncoding:NSUTF8StringEncoding]
	                          options:0
	                          error:nil];

	dispatch_async(dispatch_get_main_queue(), ^{
		NSAlert *alert = [NSAlert new];
		alert.messageText = jsonDict[@"MessageText"];
		NSString *informativeText = jsonDict[@"InformativeText"];
		NSArray *buttons = jsonDict[@"Buttons"];
		if (![buttons isEqualTo:NSNull.null] && buttons.count > 0) {
		        for (NSString *label in buttons) {
		                [alert addButtonWithTitle:label];
			}
		}

		// Check if informativeText contains markdown links and parse them
		__block NSTextView *markdownTextView = nil;
		__block BOOL hasMarkdownLinks = NO;
		if (@available(macOS 12, *)) {
		        if (informativeText.length > 0) {
		                NSError *mdError = nil;
		                NSAttributedString *mdString = [[NSAttributedString alloc]
		                        initWithMarkdownString:informativeText
		                        options:nil
		                        baseURL:nil
		                        error:&mdError];
		                if (mdString && !mdError) {
		                        // Check if the parsed result contains any links
		                        [mdString enumerateAttribute:NSLinkAttributeName
		                                inRange:NSMakeRange(0, mdString.length)
		                                options:0
		                                usingBlock:^(id value, NSRange range, BOOL *stop) {
		                                        if (value) {
		                                                hasMarkdownLinks = YES;
		                                                *stop = YES;
		                                        }
		                                }];
		                        if (hasMarkdownLinks) {
		                                // Apply system small font to match standard informativeText
		                                NSMutableAttributedString *styled = [mdString mutableCopy];
		                                NSFont *smallFont = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
		                                [styled addAttribute:NSFontAttributeName
		                                        value:smallFont
		                                        range:NSMakeRange(0, styled.length)];

		                                markdownTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 200, 0)];
		                                [markdownTextView setEditable:NO];
		                                [markdownTextView setSelectable:YES];
		                                [markdownTextView setDrawsBackground:NO];
		                                markdownTextView.textContainer.lineFragmentPadding = 0;
		                                markdownTextView.textContainerInset = NSMakeSize(0, 0);
		                                [[markdownTextView textStorage] setAttributedString:styled];
		                                [markdownTextView.layoutManager ensureLayoutForTextContainer:markdownTextView.textContainer];
		                                NSRect usedRect = [markdownTextView.layoutManager usedRectForTextContainer:markdownTextView.textContainer];
		                                [markdownTextView setFrame:NSMakeRect(0, 0, 200, ceil(usedRect.size.height))];
		                        }
		                }
		        }
		}
		if (!hasMarkdownLinks) {
		        alert.informativeText = informativeText;
		}

		NSView *accessoryView;
		NSArray *inputs = jsonDict[@"Inputs"];
		BOOL hasInputs = ![inputs isEqualTo:NSNull.null] && inputs.count > 0;
		BOOL needsAccessory = hasInputs || markdownTextView;
		if (needsAccessory) {
		        int inputsHeight = hasInputs ? 30 * (int)inputs.count : 0;
		        int textViewHeight = markdownTextView ? (int)markdownTextView.frame.size.height : 0;
		        int padding = (markdownTextView && hasInputs) ? 8 : 0;
		        int totalHeight = textViewHeight + padding + inputsHeight;
		        accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, totalHeight)];

		        if (markdownTextView) {
		                [markdownTextView setFrame:NSMakeRect(0, inputsHeight + padding, 200, textViewHeight)];
		                [accessoryView addSubview:markdownTextView];
		        }

		        if (hasInputs) {
		                BOOL first = false;
		                int y = inputsHeight;
		                for (NSDictionary *input in inputs) {
		                        y -= 30;
		                        NSString *placeholder = input[@"Placeholder"];
		                        NSInteger type = [input[@"Type"] integerValue];
		                        NSTextField *textfield;
		                        if (type == 1) {
		                                textfield = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, y, 200, 25)];
		                        } else {
		                                textfield = [[EditableNSTextField alloc] initWithFrame:NSMakeRect(0, y, 200, 25)];
		                        }
		                        [textfield setPlaceholderString:placeholder];
		                        [accessoryView addSubview:textfield];
		                        if (!first) {
		                                [alert.window setInitialFirstResponder:textfield];
		                                first = true;
					}
				}
		        }
		        [alert setAccessoryView:accessoryView];
		}

		[NSApp activateIgnoringOtherApps:YES];
		NSInteger resp = [alert runModal];
		NSMutableArray *values = [NSMutableArray new];
		if (hasInputs) {
		        for (NSView *subview in accessoryView.subviews) {
		                if (![subview isKindOfClass:[NSTextField class]]) {
		                        continue;
				}
		                [values addObject:((NSTextField *)subview).stringValue];
			}
		}
		NSData *jsonData =
			[NSJSONSerialization dataWithJSONObject:values options:0 error:nil];
		NSString *jsonString =
			[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		alertClicked(resp - NSAlertFirstButtonReturn, jsonString.UTF8String);
	});
}
