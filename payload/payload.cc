// We need to compile a dummy version for 32 bit.
// The following ifdef will make sure the file is empty,
// but only when we are compiling 32 bit on macOS.
#if __x86_64__ || _WIN32

/*
 * This is the main payload injected into the LCU.
 *
 * On Mac, this takes the form of a .dylib injected into the target
 * using the DYLD_INSERT_LIBRARIES environment variable. The dylib
 * is then able to define functions with the same name as the CEF
 * variants, which will be prioritized by dyld. We can use dlsym to
 * find the original implementation, which we can call after our
 * possible modifications.
 *
 * One note with the Mac implementation is that the dynamic linking on
 * *NIX is quite a bit more strict than on Windows. On windows, we can
 * simply say "expect some kind of dll with this exact name to be loaded".
 * On Mac, we need to provide the lib during linking, means that we need
 * precompiled binaries on Mac (unless the user somehow has a working
 * compiler setup on their system). This is not too big of a problem,
 * since the LCU rarely seems to update their CEF binary.
 *
 * On Windows, this takes the form of a .dll that replaces the original
 * libcef.dll. It delegates all but a few methods directly to the CEF
 * dll, and is able to call the original methods.
 */

#include <string> // std::string
#include <fstream> // std::ifstream
#include <streambuf> // std::istreambuf_iterator

#ifdef __APPLE__
    #include <dlfcn.h> // dlsym, RTLD_NEXT. Mac only
#else
    #include <windows.h> // Windows APIs for DLLMain.
#endif

// CEF apis.
#include "include/capi/cef_base_capi.h"
#include "include/capi/cef_app_capi.h"
#include "include/capi/cef_client_capi.h"
#include "include/capi/cef_request_handler_capi.h"

#define JAVASCRIPT_PAYLOAD getenv("ACE_PAYLOAD_PATH")

/*
 * To prevent code duplication between platforms, we define
 * a few common macros here, allowing us to abstract out platform-
 * specific injection/replacing logic.
 *
 * A broad overview of what they do:
 * OVERRIDES(function_name), used to indicate which function is overridden in the current function body:
 *   Mac: Looks up the original function and prepares it for eventual calling.
 *   Win: Does nothing.
 * cef_initialize, used as function name for the replacement cef_initialize function.
 *   Mac: cef_initialize
 *   Win: wrapped_cef_initialize
 * CEF_CREATE_BROWSER, used as function name for the replacement cef_browser_host_create_browser function.
 *   Mac: cef_browser_host_create_browser
 *   Win: wrapped_cef_browser_host_create_browser
 */
#ifdef __APPLE__
    #define DYLD_INTERPOSE(_replacement, _replacee) \
        __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
        __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };
#else
    #define DYLD_INTERPOSE(_replacement, _replacee)
#endif

#ifdef _WIN32
/*
 * Since we function as an DLL on Windows, we _have_ to implement this function.
 * Since we don't do anything interesting on attachment, we simply return TRUE.
 */
BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved) {
    return TRUE;
}
#endif

// Prevent name-mangling.
extern "C" {
    // We replace the request_handler, which may or may not have been set previously.
    // Just in case the handler does anything important, we store the previous instance
    // and invoke it just like normal.
    static cef_request_handler_t* (CEF_CALLBACK *old_request_handler)(cef_client_t* self);

    // This function is called before any request is made. We register this monitor with
    // CEF so we can run code just _before_ the first plugin is fetched. An environment
    // variable is used to determine which payload to inject, if any.
    cef_return_value_t CEF_CALLBACK on_before_resource_load(cef_request_handler_t* self, cef_browser_t* browser, cef_frame_t* frame, cef_request_t* request, cef_request_callback_t* callback) {
	    // We have to do this workaround to get from the LCU 16-bit CEF strings to
	    // the 8-bit strings (char*s) that C++ uses. 
	    cef_string_userfree_t url = request->get_url(request);
        cef_string_utf8_t str = {};
        cef_string_utf16_to_utf8(url->str, url->length, &str);

	    // This is a crude but effective way to check if we are loading
	    // what seems to be a plugin.
	    if (strstr(str.str, "/fe/") && strstr(str.str, "/index.html") && JAVASCRIPT_PAYLOAD) {
		    // Read the code that has to be injected and replace __URL__ with the appropriate environment var.
            std::ifstream fin(JAVASCRIPT_PAYLOAD);
            std::string code((std::istreambuf_iterator<char>(fin)), std::istreambuf_iterator<char>());

		    // Convert the 8-bit string back to the CEF string type.
		    cef_string_t js_str = {};
		    cef_string_from_ascii(code.c_str(), code.length(), &js_str);
		    frame->execute_java_script(frame, &js_str, url, 0);
	    }

	    // Free the URL that we asked for earlier.
	    cef_string_userfree_free(url);

        // Allow the request.
	    return RV_CONTINUE;
    }

    // This is our version of the request_handler that we will inject into the CEF process.
    // We override this to simply gain access to the `on_before_resource_load` callback.
    // We query the old request handler, in case Riot has it set to something besides the default.
    cef_request_handler_t* CEF_CALLBACK get_request_handler(cef_client_t* self) {
	    cef_request_handler_t null_handler = {};
	    cef_request_handler_t* ret = old_request_handler ? old_request_handler(self) : &null_handler;
	    ret->on_before_resource_load = on_before_resource_load;

	    return ret;
    }

    // Called at the very start before any other cef_** functions are ran.
    // We use this to enable remote debugging and the ignoring of certificate errors.
    // TODO(molenzwiebel): Change ignore_certificate_errors to a custom callback
    // on the cef_request_handler_t struct instead.
    int CEF_EXPORT wrapped_cef_initialize(const cef_main_args_t* args, const cef_settings_t* settings, cef_app_t* application, void* windows_sandbox_info) {
#ifdef __APPLE__
        // Copy over the old arguments.
        char** new_args = new char*[args->argc + 1];
        for (int i = 0; i < args->argc; i++) {
            new_args[i] = args->argv[i];
        }

        // Add `--allow-running-insecure-content` so we can serve our payload over HTTP.
        new_args[args->argc] = "--allow-running-insecure-content";

        // Write the new args. Note that we need to cast away the const specifier.
        ((cef_main_args_t*) args)->argv = new_args; 
        ((cef_main_args_t*) args)->argc++;
#else
		// TODO(molenzwiebel): This is very, very, very, very, very, very, very (cont)
		// very, very, very, very, very, very dirty and undefined behavior. FIX THIS.
		// It is literally a wonder that this does not cause buffer overflows.
		LPTSTR arg_ptr = GetCommandLineW();
		LPTSTR extra = L" --allow-running-insecure-content";
		wcsncat(arg_ptr, extra, lstrlenW(extra));
#endif

        cef_settings_t* mutable_settings = (cef_settings_t*) settings;
        mutable_settings->remote_debugging_port = 8888;
        mutable_settings->ignore_certificate_errors = 1;

        return cef_initialize(args, settings, application, windows_sandbox_info);
    }

    // Interpose new function, does nothing on windows.
    DYLD_INTERPOSE(wrapped_cef_initialize, cef_initialize);

    // Called when a new browser host is created. We hook this to insert our
    // own request handler, which is then able to insert Ace before any plugin loads.
    int wrapped_cef_browser_host_create_browser(const cef_window_info_t* window_info, cef_client_t* client, const cef_string_t* url, const cef_browser_settings_t* settings, cef_request_context_t* request_context) {	
	    old_request_handler = client->get_request_handler;
	    client->get_request_handler = get_request_handler;

	    return cef_browser_host_create_browser(window_info, client, url, settings, request_context);
    }

    // Interpose new function, does nothing on windows.
    DYLD_INTERPOSE(wrapped_cef_browser_host_create_browser, cef_browser_host_create_browser);
}

#endif // __x86_64__ || _WIN32