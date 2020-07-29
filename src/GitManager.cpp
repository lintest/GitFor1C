#include "GitManager.h"
#include "json_ext.h"

#include <stdexcept>
#include <iostream>
#include <cstring>
#include <string>
#include <thread>

#ifdef WIN32
#include <windows.h>
#include <conio.h>
#endif // WIN32

#pragma comment(lib, "git2")
#pragma comment(lib, "msvcrtd")
#pragma comment(lib, "crypt32")
#pragma comment(lib, "rpcrt4")
#pragma comment(lib, "winhttp")

#define S(wstr) WC2MB(wstr).c_str()

GitManager::GitManager(AddInNative* addin)
{
	m_addin = addin;
	git_libgit2_init();
}

GitManager::~GitManager()
{
	if (m_repo) git_repository_free(m_repo);
	git_libgit2_shutdown();
}

std::wstring GitManager::success(int error)
{
	if (error >= 0) return {};
	const git_error* e = git_error_last();
	nlohmann::json json, j;
	j["code"] = e->klass;
	j["message"] = e->message;
	json["error"] = j;
	return MB2WC(json.dump());
}

std::wstring GitManager::error(std::string message)
{
	nlohmann::json json, j;
	j["message"] = message;
	json["error"] = j;
	return MB2WC(json.dump());
}

std::wstring GitManager::error()
{
	return error("Repo is null");
}

std::wstring GitManager::init(const std::wstring& path, bool is_bare)
{
	if (m_repo) git_repository_free(m_repo);
	return success(git_repository_init(&m_repo, S(path), is_bare));
}

std::wstring GitManager::clone(const std::wstring& url, const std::wstring& path)
{
	if (m_repo) git_repository_free(m_repo);
	return success(git_clone(&m_repo, S(url), S(path), NULL));
}

std::wstring GitManager::open(const std::wstring& path)
{
	if (m_repo) git_repository_free(m_repo);
	return success(git_repository_open(&m_repo, S(path)));
}

std::wstring GitManager::find(const std::wstring& path)
{
	git_buf root = { 0 };
	int ok = git_repository_discover(&root, S(path), 0, nullptr);
	if (ok < 0) return success(ok);
	nlohmann::json json, j;
	j["path"] = root.ptr;
	json["result"] = j;
	return MB2WC(json.dump());
}

static std::string getStatusText(git_status_t status) {
	switch (status) {
	case GIT_STATUS_CURRENT: return "CURRENT";
	case GIT_STATUS_INDEX_NEW: return "INDEX_NEW";
	case GIT_STATUS_INDEX_MODIFIED: return "INDEX_MODIFIED";
	case GIT_STATUS_INDEX_DELETED: return "INDEX_DELETED";
	case GIT_STATUS_INDEX_RENAMED: return "INDEX_RENAMED";
	case GIT_STATUS_INDEX_TYPECHANGE: return "INDEX_TYPECHANGE";
	case GIT_STATUS_WT_NEW: return "WT_NEW";
	case GIT_STATUS_WT_MODIFIED: return "WT_MODIFIED";
	case GIT_STATUS_WT_DELETED: return "WT_DELETED";
	case GIT_STATUS_WT_TYPECHANGE: return "WT_TYPECHANGE";
	case GIT_STATUS_WT_RENAMED: return "WT_RENAMED";
	case GIT_STATUS_WT_UNREADABLE: return "WT_UNREADABLE";
	case GIT_STATUS_IGNORED: return "IGNORED";
	case GIT_STATUS_CONFLICTED: return "CONFLICTED";
	default: return {};
	}
}

int status_cb(const char* path, unsigned int status_flags, void* payload)
{
	nlohmann::json* json = (nlohmann::json*)payload;
	nlohmann::json j, statuses;
	for (unsigned int i = 0; i < 16; i++) {
		git_status_t status = git_status_t(1u << i);
		if (status & status_flags) {
			statuses.push_back(getStatusText(status));
		}
	}
	j["filepath"] = path;
	j["statuses"] = statuses;
	json->push_back(j);
	return 0;
}

std::wstring GitManager::status()
{
	if (!m_repo) return error();
	nlohmann::json json, j;
	int ok = git_status_foreach(m_repo, status_cb, &j);
	if (ok < 0) return success(ok);
	json["result"] = j;
	return MB2WC(json.dump());
}

std::wstring GitManager::commit(const std::wstring& msg)
{
	if (!m_repo) return error();
	git_signature* sig;
	git_index* index;
	git_oid tree_id, commit_id;
	git_tree* tree;
	git_object* head_commit;
	git_revparse_single(&head_commit, m_repo, "HEAD^{commit}");
	git_commit* commit = (git_commit*)head_commit;
	size_t head_count = head_commit ? 1 : 0;
	int ok = git_signature_default(&sig, m_repo);
	if (ok < 0) return error("Unable to create a commit signature");
	ok = git_repository_index(&index, m_repo);
	if (ok < 0) return error("Could not open repository index");
	ok = git_index_write_tree(&tree_id, index);
	if (ok < 0) return error("Unable to write initial tree from index");
	ok = git_tree_lookup(&tree, m_repo, &tree_id);
	if (ok < 0) return error("Could not look up initial tree");
	ok = git_commit_create_v(&commit_id, m_repo, "HEAD", sig, sig, NULL, S(msg), tree, head_count, head_commit);
	if (ok < 0) return success(ok);
	if (ok < 0) return error("Could not create the initial commit");
	git_index_free(index);
	git_tree_free(tree);
	git_signature_free(sig);
	return {};
}

std::wstring GitManager::add(const std::wstring& filepath)
{
	if (!m_repo) return error();
	git_index* index;
	int ok = git_repository_index(&index, m_repo);
	if (ok < 0) return success(ok);
	ok = git_index_add_bypath(index, S(filepath));
	if (ok < 0) return success(ok);
	ok = git_index_write(index);
	if (ok < 0) return success(ok);
	return {};
}

std::wstring GitManager::remove(const std::wstring& filepath)
{
	if (!m_repo) return error();
	git_index* index;
	int ok = git_repository_index(&index, m_repo);
	if (ok < 0) return success(ok);
	ok = git_index_remove_bypath(index, S(filepath));
	if (ok < 0) return success(ok);
	ok = git_index_write(index);
	if (ok < 0) return success(ok);
	return {};
}

std::string oid2str(const git_oid* id) 
{
	const size_t size = GIT_OID_HEXSZ + 1;
	char buf[size];
	git_oid_tostr(buf, size, id);
	return buf;
}

std::wstring GitManager::info(const std::wstring& spec)
{
	if (!m_repo) return error();
	git_object* head_commit;
	int ok = git_revparse_single(&head_commit, m_repo, S(spec));
	if (ok < 0) return success(ok);
	git_commit* commit = (git_commit*)head_commit;
	const git_oid* tree_id = git_commit_tree_id(commit);
	const git_signature* author = git_commit_author(commit);
	nlohmann::json json, j;
	j["id"] = oid2str(tree_id);
	j["author.name"] = author->name;
	j["author.email"] = author->email;
	j["message"] = git_commit_message(commit);
	json["result"] = j;
	git_commit_free(commit);
	return MB2WC(json.dump());
}

std::wstring GitManager::history(const std::wstring& spec)
{
	if (!m_repo) return error();
	git_object* head_commit;
	int ok = git_revparse_single(&head_commit, m_repo, S(spec));
	if (ok < 0) return success(ok);

	git_oid oid;
	git_revwalk* walker;

	git_revwalk_new(&walker, m_repo);
	git_revwalk_sorting(walker, GIT_SORT_TIME);
	git_revwalk_push_head(walker);

	nlohmann::json json, list;
	while (git_revwalk_next(&oid, walker) == 0) {
		git_commit* commit;
		int ok = git_commit_lookup(&commit, m_repo, &oid);
		if (ok < 0) return success(ok);
		const git_oid* tree_id = git_commit_tree_id(commit);
		const git_signature* author = git_commit_author(commit);
		const git_signature* committer = git_commit_committer(commit);
		nlohmann::json j;
		j["id"] = oid2str(tree_id);
		j["authorName"] = author->name;
		j["authorEmail"] = author->email;
		j["committerName"] = committer->name;
		j["committerEmail"] = committer->email;
		j["time"] = git_commit_time(commit);
		j["message"] = git_commit_message(commit);
		git_commit_free(commit);
		list.push_back(j);
	}
	git_revwalk_free(walker);
	json["result"] = list;
	return MB2WC(json.dump());
}
