import { createRequire } from "node:module";
import * as path from "node:path";
import { getNativeModuleCandidates } from "./native-module-path.ts";

const cjsRequire = createRequire(import.meta.url);

export type ModifierKey = "shift" | "command" | "control" | "option";

export interface NativeClipboard {
	/** Undefined means unavailable, null means no text; transfer failures reject. */
	getText(): Promise<string | null | undefined>;
	/** Undefined means unavailable, null means no image; transfer failures reject. */
	getImage(): Promise<Uint8Array | null | undefined>;
	/** Linux uses command-line tools to retain clipboard ownership instead. */
	setText?(text: string): Promise<void>;
}

type NativePlatformHelper = NativeClipboard & {
	enableVirtualTerminalInput?: () => boolean;
	isModifierPressed?: (name: ModifierKey) => boolean;
};

// Cache module loading, not display availability: a disconnected display can recover.
const helpers = new Map<string, NativePlatformHelper | undefined>();

function loadNativePlatformHelper(platform: string, suffix = ""): NativePlatformHelper | undefined {
	const arch = process.arch;
	// "arm" is the 32-bit ARM (armv7l/armv6l) build: no prebuild ships for it, but an operator who
	// compiles one locally (see native/linux/build.sh) should be able to use it. Without a helper the
	// require below fails and this returns undefined, exactly as before.
	if (arch !== "x64" && arch !== "arm64" && arch !== "arm") return undefined;
	const nativePath = path.join(
		"native",
		platform,
		"prebuilds",
		`${platform}-${arch}`,
		`${platform}-platform${suffix}.node`,
	);
	if (helpers.has(nativePath)) return helpers.get(nativePath);

	for (const modulePath of getNativeModuleCandidates(nativePath)) {
		try {
			const helper = cjsRequire(modulePath) as Partial<NativePlatformHelper> | null;
			if (typeof helper?.getText === "function" && typeof helper.getImage === "function") {
				helpers.set(nativePath, helper as NativePlatformHelper);
				return helper as NativePlatformHelper;
			}
		} catch {
			// Try the next possible packaging location.
		}
	}
	helpers.set(nativePath, undefined);
	return undefined;
}

export function getNativePlatformHelper(): NativePlatformHelper | undefined {
	if (process.platform !== "darwin" && process.platform !== "win32") return undefined;
	return loadNativePlatformHelper(process.platform);
}

/** Load a clipboard helper without opening the display until a read is requested. */
export function getNativeClipboard(): NativeClipboard | undefined {
	if (process.platform !== "linux") return getNativePlatformHelper();
	if (!process.env.DISPLAY) return undefined;
	return loadNativePlatformHelper("linux", "-x11");
}
