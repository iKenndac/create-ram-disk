//
//  main.m
//  create-ram-disk
//
//  Created by Daniel Kennett on 26/06/14.
//  For license information, see LICENSE.markdown

#import <Foundation/Foundation.h>

#pragma mark Helpers

BOOL fileExistsAtPath(NSString *path) {
	return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

BOOL checkRamDiskSizeStringIsValid(NSString *sizeString) {
	return (sizeString.length > 2) &&
	([sizeString hasSuffix:@"MB"] || [sizeString hasSuffix:@"GB"]) &&
	([[sizeString substringToIndex:sizeString.length - 2] integerValue] > 0);
}

BOOL checkVolumesAvailable() {
	return [[NSFileManager defaultManager] fileExistsAtPath:@"/Volumes"];
}

BOOL checkVolumesWriteable() {
	return [[NSFileManager defaultManager] isWritableFileAtPath:@"/Volumes/"];
}

NSInteger blockCountForSizeString(NSString *sizeString) {

	if (!checkRamDiskSizeStringIsValid(sizeString)) {
		return 0;
	}

	return [[sizeString substringToIndex:sizeString.length - 2] integerValue] * 2000;
}

NSInteger waitCountForString(NSString *string) {
	return [string integerValue];
}

BOOL checkVolumesAvailableAndWriteable(NSInteger waitCount) {

	if (checkVolumesAvailable() && checkVolumesWriteable()) {
		return true;
	}

	NSInteger waits = 0;

	while (waits < waitCount) {
		printf("WARNING: /Volumes not available. Waiting…\n");
		sleep(1);
		waits++;

		if (checkVolumesAvailable() && checkVolumesWriteable()) {
			return true;
		}
	}

	printf("ERROR: /Volumes not available.\n");
	return false;
}

BOOL createRamDiskWithBlockCount(NSInteger blocks, NSString **outPath) {

	if (blocks == 0) {
		return NO;
	}

	NSPipe *pipe = [NSPipe pipe];
	NSTask *task = [NSTask new];
	task.launchPath = @"/usr/bin/hdiutil";
	task.arguments = @[@"attach", @"-nomount", [NSString stringWithFormat:@"ram://%@", @(blocks)]];
	task.standardOutput = pipe;
	[task launch];
	[task waitUntilExit];

	if (task.terminationStatus == 0) {

		NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
		NSString *path = [[[NSString alloc] initWithData:data
												encoding:NSUTF8StringEncoding]
						  stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		if (outPath != NULL) {
			*outPath = path;
		}
	}

	return task.terminationStatus == 0;
}

BOOL formatRamDiskWithNameAtPath(NSString *name, NSString *path, NSString **output) {

	if (name.length == 0 || path.length == 0) {
		if (output != NULL) {
			*output = @"Invalid input";
		}
		return NO;
	}

	NSPipe *pipe = [NSPipe pipe];
	NSTask *task = [NSTask new];
	task.launchPath = @"/usr/sbin/diskutil";
	task.arguments = @[@"quiet", @"erasevolume", @"HFS+", name, path];
	task.standardOutput = pipe;
	[task launch];
	[task waitUntilExit];

	if (task.terminationStatus == 0) {

		NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
		NSString *path = [[[NSString alloc] initWithData:data
												encoding:NSUTF8StringEncoding]
						  stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		if (output != NULL) {
			*output = path;
		}
	}

	return task.terminationStatus == 0;
}

BOOL ejectRamDiskAtPath(NSString *path) {

	if (path.length == 0) {
		return NO;
	}

	NSTask *task = [NSTask new];
	task.launchPath = @"/usr/sbin/diskutil";
	task.arguments = @[@"eject", path];
	task.standardOutput = [NSPipe pipe];
	[task launch];
	[task waitUntilExit];

	return task.terminationStatus == 0;
}

#pragma mark - Usage

void printUsage() {

	NSString *processName = [[NSProcessInfo processInfo] processName];

	printf("%s by Daniel Kennett\n\n", processName.UTF8String);

	printf("Creates and mounts RAM disk with the given name and size.\n\n");

	printf("WARNING: The RAM disk's contents will be lost if the disk is\n");
	printf("unmounted or the computer is shut down or restarted.\n\n");

	printf("Usage: %s -name <RAM disk name> -size <size>\n", processName.UTF8String);
	printf("       %s [-wait <seconds>]\n\n", [@"" stringByPaddingToLength:processName.length
																withString: @" "
														   startingAtIndex:0].UTF8String);

	printf("  -name   The name of the RAM disk. Will be used as the mount\n");
	printf("          point and the volume's label.\n\n");

	printf("  -size   The size of the RAM disk. Value must be a nonzero\n");
	printf("          integer followed by 'MB' or 'GB', such as '500MB'\n");
	printf("          or '2GB'.\n\n");

	printf("  -wait   A positive number of seconds to wait for /Volumes\n");
	printf("          to become available. Can be helpful if executing\n");
	printf("          at startup.");

	printf("\n\n");
}

#pragma mark - Main

int main(int argc, const char * argv[])
{

	@autoreleasepool {

	    NSString *ramDiskName = [[NSUserDefaults standardUserDefaults] valueForKey:@"name"];
		NSString *ramDiskSizeString = [[NSUserDefaults standardUserDefaults] valueForKey:@"size"];
		NSString *waitCountString = [[NSUserDefaults standardUserDefaults] valueForKey:@"wait"];
		NSString *ramDiskMountPoint = [NSString stringWithFormat:@"/Volumes/%@", ramDiskName];

		NSInteger waitCount = waitCountForString(waitCountString);

		if (ramDiskName.length == 0 || !checkRamDiskSizeStringIsValid(ramDiskSizeString) ||
			(waitCountString != nil && waitCount == 0) ||
			waitCount <= 0) {
			printUsage();
			exit(EXIT_FAILURE);
		}

		// ---- Check if system is ready (/Volumes might not exist early in boot process) ----

		if (!checkVolumesAvailableAndWriteable(waitCount)) {
			// ^ Prints its own error output
			exit(EXIT_FAILURE);
		}

		// ---- Check if RAM Disk exists ----

		if (fileExistsAtPath(ramDiskMountPoint)) {
			printf("ERROR: RAM disk with this name already exists.\n");
			exit(EXIT_FAILURE);
		}

		// ---- Create the RAM Disk ----

		printf("Creating RAM disk… ");

		NSString *devPath = nil;
		if (!createRamDiskWithBlockCount(blockCountForSizeString(ramDiskSizeString), &devPath)) {
			printf("failed.\n");
			exit(EXIT_FAILURE);
		}

		printf("done (%s).\n", devPath.UTF8String);

		// ---- Format the RAM Disk ----

		printf("Formatting RAM disk… ");
		NSString *output = nil;
		if (!formatRamDiskWithNameAtPath(ramDiskName, devPath, &output)) {
			printf("failed.\n");

			printf("Cleaning up… ");
			if (!ejectRamDiskAtPath(devPath)) {
				printf("failed.\n");
			} else {
				printf("done.\n");
			}

			exit(EXIT_FAILURE);
		}

		if (fileExistsAtPath(ramDiskMountPoint)) {
			printf("done (%s).\n", ramDiskMountPoint.UTF8String);
		} else {
			printf("done.\n");
			printf("WARNING: All processes reported success but\n");
			printf("RAM disk not found at expected location.\n");
		}
	    
	}
    return 0;
}
